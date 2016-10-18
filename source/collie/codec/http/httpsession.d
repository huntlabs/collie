module collie.codec.http.httpsession;

import collie.codec.http.headers;
import collie.codec.http.httpmessage;
import collie.codec.http.httptansaction;
import collie.codec.http.codec.httpcodec;
import collie.channel;
import collie.codec.http.errocode;

import collie.socket.tcpsocket;
import std.socket;

/// HTTPSession will not send any read event
abstract class HTTPSession : HandlerAdapter!(ubyte[]), 
	HTTPTransaction.Transport,
	HTTPCodec.CallBack
{
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
		void onPingReplySent(int64_t latency);
		void onPingReplyReceived();
		void onSettingsOutgoingStreamsFull(HTTPSession);
		void onSettingsOutgoingStreamsNotFull(HTTPSession);
		void onFlowControlWindowClosed(HTTPSession);
		void onEgressBuffered(HTTPSession);
		void onEgressBufferCleared(HTTPSession);
	}

	this()
	{
	}

	//HandlerAdapter {
	override void read(Context ctx,ubyte[] msg) {

	}

	override void transportActive(Context ctx) {
		TCPSocket sock = cast(TCPSocket)context.pipeline.transport;
		if(sock is null){ 
			_localAddr = new UnknownAddress();
			_peerAddr = _localAddr;
		} else {
			_localAddr = sock.localAddress;
			_peerAddr = sock.remoteAddress;
		}
	}

	override void transportInactive(Context ctx) {

	}

	override void timeOut(Context ctx) {

	}

	//HandlerAdapter}
	//HTTPTransaction.Transport, {
	override  void pauseIngress(HTTPTransaction txn){}
	
	override void resumeIngress(HTTPTransaction txn){}
	
	override void transactionTimeout(HTTPTransaction txn){}
	
	override void sendHeaders(HTTPTransaction txn,
		const HTTPMessage headers,
		//HTTPHeaderSize* size,
		bool eom){}
	
	override size_t sendBody(HTTPTransaction txn,
		ubyte[],
		bool eom){}
	
	override size_t sendChunkHeader(HTTPTransaction txn,size_t length)
	{}
	
	override size_t sendChunkTerminator(HTTPTransaction txn)
	{}
	
	
	override size_t sendEOM(HTTPTransaction txn)
	{}
	
	//		size_t sendAbort(HTTPTransaction txn,
	//			HTTPErrorCode statusCode);
	
	override void sendWsBinary(ubyte[] data)
	{}
	
	override void sendWsText(string data)
	{}
	
	override void sendWsPing(ubyte[] data)
	{}
	
	override void sendWsPong(ubyte[] data)
	{}
	
	override void notifyPendingEgress()
	{}
	
	override void detach(HTTPTransaction txn)
	{}
	
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
	
	override bool isDraining(){}
	//HTTPTransaction.Transport, }


	// HTTPCodec.CallBack {
	override void onMessageBegin(StreamID stream, HTTPMessage msg)
	{}

	override void onPushMessageBegin(StreamID stream,
		StreamID assocStream,
		HTTPMessage* msg)
	{}

	override void onHeadersComplete(StreamID stream,
		HTTPMessage msg){}

	override void onBody(StreamID stream,const ubyte[] data){
		HTTPTransaction tran = _transactions.get(stream,null);
		if(tran)
			tran.onIngressBody(data,0);
	}

	override void onChunkHeader(StreamID stream, size_t length){}

	override void onChunkComplete(StreamID stream){}

	override void onMessageComplete(StreamID stream, bool upgrade){}

	override void onError(StreamID stream,string erromsg){}

	override void onAbort(StreamID stream,
		HTTPErrorCode code){}
	
	override void onWsFrame(StreamID,ref WSFrame){}
	
	override void onWsPing(StreamID,ref WSFrame){}
	
	override void onWsPong(StreamID,ref WSFrame){}
	// HTTPCodec.CallBack }
protected:
	/**
   * Called by onHeadersComplete(). This function allows downstream and
   * upstream to do any setup (like preparing a handler) when headers are
   * first received from the remote side on a given transaction.
   */
	void setupOnHeadersComplete(HTTPTransaction txn,
		HTTPMessage msg);
	
	/**
   * Called by handleErrorDirectly (when handling parse errors) if the
   * transaction has no handler.
   */
	HTTPTransactionHandler getParseErrorHandler(
		HTTPTransaction txn, const string error);
	
	/**
   * Called by transactionTimeout if the transaction has no handler.
   */
	HTTPTransactionHandler getTransactionTimeoutHandler(
		HTTPTransaction txn);

protected:
	HTTPTransaction[HTTPCodec.StreamID] _transactions;
	Address _localAddr;
	Address _peerAddr;
	HTTPCodec _codec;
}

