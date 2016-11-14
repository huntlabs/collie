module collie.codec.http.session.httpsession;

import collie.codec.http.headers;
import collie.codec.http.httpmessage;
import collie.codec.http.httptansaction;
import collie.codec.http.codec.httpcodec;
import collie.codec.http.codec.wsframe;
import collie.codec.http.errocode;

import collie.socket.tcpsocket;
import collie.utils.functional;
import std.socket;


abstract class HTTPSessionController
{
	HTTPTransactionHandler getRequestHandler(HTTPTransaction txn, HTTPMessage msg);

	void attachSession(HTTPSession session){}
	
	/**
   * Informed at the end when the given HTTPSession is going away.
   */
	void detachSession(HTTPSession session){}
	
	/**
   * Inform the controller that the session's codec changed
   */
	void onSessionCodecChange(HTTPSession session) {}
}

interface SessionDown
{
	void httpWrite(ubyte[],void delegate(ubyte[],size_t));
	void httpClose();
	Address localAddress();
	Address remoteAddress();
}

/// HTTPSession will not send any read event
abstract class HTTPSession : HTTPTransaction.Transport,
	HTTPCodec.CallBack
{
	alias HVector = HTTPCodec.HVector;
	alias StreamID = HTTPCodec.StreamID;
	interface InfoCallback {
		// Note: you must not start any asynchronous work from onCreate()
		void onCreate(HTTPSession);
		//void onIngressError(const HTTPSession, ProxygenError);
		void onIngressEOF();
		void onRequestBegin(HTTPSession);
		void onRequestEnd(HTTPSession,
			uint maxIngressQueueSize);
		void onActivateConnection(HTTPSession);
		void onDeactivateConnection(HTTPSession);
		// Note: you must not start any asynchronous work from onDestroy()
		void onDestroy(HTTPSession);
		void onIngressMessage(HTTPSession,
			HTTPMessage);
		void onIngressLimitExceeded(HTTPSession);
		void onIngressPaused(HTTPSession);
		void onTransactionDetached(HTTPSession);
		void onPingReplySent(ulong latency);
		void onPingReplyReceived();
		void onSettingsOutgoingStreamsFull(HTTPSession);
		void onSettingsOutgoingStreamsNotFull(HTTPSession);
		void onFlowControlWindowClosed(HTTPSession);
		void onEgressBuffered(HTTPSession);
		void onEgressBufferCleared(HTTPSession);
	}

	this(HTTPSessionController controller,HTTPCodec codec,SessionDown down)
	{
		_controller = controller;
		_down = down;
		_codec = codec;
		_codec.setCallback(this);
	}

	//HandlerAdapter {
	void onRead(ubyte[] msg) {
		_codec.onIngress(msg);
	}

	void onActive() {
		_localAddr = _down.localAddress;
		_peerAddr = _down.remoteAddress;
	}

	void inActive() {
		if(_transaction) {
			_transaction.onErro(HTTPErrorCode.REMOTE_CLOSED);
			//_transaction.onDelayedDestroy();
		}
		trace("connect closed!");
	}

	void onTimeout() @trusted {
		if(_transaction){
			_transaction.onErro(HTTPErrorCode.TIME_OUT);
		}
	}

	//HandlerAdapter}
	//HTTPTransaction.Transport, {
	override  void pauseIngress(HTTPTransaction txn){}
	
	override void resumeIngress(HTTPTransaction txn){}
	
	override void transactionTimeout(HTTPTransaction txn){}
	
	override void sendHeaders(HTTPTransaction txn,
		HTTPMessage headers,
		bool eom)
	{
		HVector tdata;
		_codec.generateHeader(txn.streamID,headers,tdata,eom);
		_down.httpWrite(tdata.data(true),bind(&writeCallBack,eom,txn));
	}

	override size_t sendBody(HTTPTransaction txn,ref HVector body_,bool eom) {
		size_t rlen = getCodec.generateBody(txn.streamID,body_,eom);
		_down.httpWrite(body_.data(true),bind(&writeCallBack,eom,txn));
		return rlen;
	}
	
	override size_t sendBody(HTTPTransaction txn,
		ubyte[] data,
		bool eom)
	{
		HVector tdata = HVector(data,true);
		size_t rlen = getCodec.generateBody(txn.streamID,tdata,eom);
		_down.httpWrite(tdata.data(true),bind(&writeCallBack,eom,txn));
		return rlen;
	}
	
	override size_t sendChunkHeader(HTTPTransaction txn,size_t length)
	{
		HVector tdata;
		size_t rlen = getCodec.generateChunkHeader(txn.streamID,tdata,length);
		_down.httpWrite(tdata.data(true),bind(&writeCallBack,false,txn));
		return rlen;
	}

	
	override size_t sendChunkTerminator(HTTPTransaction txn)
	{
		HVector tdata;
		size_t rlen = getCodec.generateChunkTerminator(txn.streamID,tdata);
		_down.httpWrite(tdata.data(true),bind(&writeCallBack,true,txn));
		return rlen;
	}
	
	
	override size_t sendEOM(HTTPTransaction txn)
	{
		trace("send eom!!");
		HVector tdata;
		size_t rlen = getCodec.generateEOM(txn.streamID,tdata);
		if(rlen)
			_down.httpWrite(tdata.data(true),bind(&writeCallBack,true,txn));
		return rlen;
	}

	//		size_t sendAbort(HTTPTransaction txn,
	//			HTTPErrorCode statusCode);

	override void socketWrite(HTTPTransaction txn,ubyte[] data,HTTPTransaction.Transport.SocketWriteCallBack cback) {
		_down.httpWrite(data,cback);
	}


	override void sendWsBinary(HTTPTransaction txn,ubyte[] data)
	{
	}
	
	override void sendWsText(HTTPTransaction txn,string data)
	{}
	
	override void sendWsPing(HTTPTransaction txn,ubyte[] data)
	{}
	
	override void sendWsPong(HTTPTransaction txn,ubyte[] data)
	{}
	
	override void notifyPendingEgress()
	{}
	
	override void detach(HTTPTransaction txn)
	{
		if(txn is _transaction)
			_transaction = null;
	}
	
	//		void notifyIngressBodyProcessed(uint32_t bytes);
	//		
	//		void notifyEgressBodyBuffered(int64_t bytes);
	
	override Address getLocalAddress(){
		return _localAddr;
	}
	
	override Address getPeerAddress(){
		return _peerAddr;
	}
	
	
	override HTTPCodec getCodec(){
		return _codec;
	}
	
	override bool isDraining(){return false;}
	//HTTPTransaction.Transport, }


	// HTTPCodec.CallBack {
	override void onMessageBegin(StreamID stream, HTTPMessage msg)
	{
		//_transaction = new HTTPTransaction(_codec.getTransportDirection,stream,0,this);
		trace("begin a http requst or reaponse!");
	}

	override void onHeadersComplete(StreamID stream,
		HTTPMessage msg){
		trace("onHeadersComplete ------");
		_transaction = new HTTPTransaction(_codec.getTransportDirection,stream,0,this);
		setupOnHeadersComplete(_transaction,msg);
	}

	override void onBody(StreamID stream,const ubyte[] data){
		//HTTPTransaction tran = _transactions.get(stream,null);
		if(_transaction)
			_transaction.onIngressBody(data,cast(ushort)0);
	}

	override void onChunkHeader(StreamID stream, size_t length){
		if(_transaction)
			_transaction.onIngressChunkHeader(length);
	}

	override void onChunkComplete(StreamID stream){
		if(_transaction)
			_transaction.onIngressChunkComplete();
	}

	override void onMessageComplete(StreamID stream, bool upgrade){
		if(_transaction)
			_transaction.onIngressEOM();
	}

	override void onError(StreamID stream,HTTPErrorCode code){
		//if(_transaction)
		//	_transaction.
		_down.httpClose();
	}

	override void onAbort(StreamID stream,
		HTTPErrorCode code){
		_down.httpClose();
	}
	
	override void onWsFrame(StreamID,ref WSFrame){

	}
	
	override void onWsPing(StreamID,ref WSFrame){}
	
	override void onWsPong(StreamID,ref WSFrame){}

	override bool onNativeProtocolUpgrade(StreamID stream,
		CodecProtocol protocol,
		string protocolString,
		HTTPMessage msg)
	{
		return false;
	}
	// HTTPCodec.CallBack }
protected:
	/**
   * Called by onHeadersComplete(). This function allows downstream and
   * upstream to do any setup (like preparing a handler) when headers are
   * first received from the remote side on a given transaction.
   */
	void setupOnHeadersComplete(ref HTTPTransaction txn,
		HTTPMessage msg);

protected:
	void writeCallBack(bool isLast,HTTPTransaction txn,ubyte[] data,size_t size)
	{
		//trace(cast(string)data);
		import collie.utils.memory;
		gcFree(data);
		if(isLast && txn)
			txn.onDelayedDestroy();
		if(isLast && _codec.shouldClose) {
			trace("\t\t --------do close!!!");
			_down.httpClose();
		}
	}
protected:
	//HTTPTransaction[HTTPCodec.StreamID] _transactions;
	HTTPTransaction _transaction;
	Address _localAddr;
	Address _peerAddr;
	HTTPCodec _codec;

	HTTPSessionController _controller;
	SessionDown _down;
}

