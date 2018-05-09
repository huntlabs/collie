/*
 * Collie - An asynchronous event-driven network framework using Dlang development
 *
 * Copyright (C) 2015-2017  Shanghai Putao Technology Co., Ltd 
 *
 * Developer: putao's Dlang team
 *
 * Licensed under the Apache-2.0 License.
 *
 */
module collie.codec.http.session.httpsession;

import collie.codec.http.headers;
import collie.codec.http.httpmessage;
import collie.codec.http.httptansaction;
import collie.codec.http.codec.httpcodec;
import collie.codec.http.codec.wsframe;
import collie.codec.http.errocode;
import kiss.logger;

import kiss.net.TcpStream;
import kiss.util.functional;
import kiss.net;
import kiss.event.core;
import kiss.event.task;
import std.socket;
import std.experimental.allocator.mallocator;
import collie.codec.http.httpwritebuffer;

alias HTTPBuffer =  HTTPByteBuffer!(Mallocator);
abstract class HTTPSessionController
{
	HTTPTransactionHandler getRequestHandler(HTTPTransaction txn, HTTPMessage msg);

	void attachSession(HTTPSession session){}
	
	/**
   * logInformed at the end when the given HTTPSession is going away.
   */
	void detachSession(HTTPSession session){}
	
	/**
   * logInform the controller that the session's codec changed
   */
	void onSessionCodecChange(HTTPSession session) {}
}

interface SessionDown
{
	void httpWrite(StreamWriteBuffer buffer);
	void httpClose();
	void post(void delegate());
	Address localAddress();
	Address remoteAddress();
}

/// HTTPSession will not send any read event
abstract class HTTPSession : HTTPTransaction.Transport,
	HTTPCodec.CallBack
{
	alias StreamID = HTTPCodec.StreamID;
	interface logInfoCallback {
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
		//logDebug("on read: ", cast(string)msg);
		_codec.onIngress(msg);
	}

	void onActive() {
		_localAddr = _down.localAddress;
		_peerAddr = _down.remoteAddress;
	}

	void inActive() {
		getCodec.onConnectClose();
		version(CollieDebugMode) logDebug("connection closed!");
	}

	void onTimeout() @trusted {
		if(_codec)
			_codec.onTimeOut();
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
		auto tdata = new HTTPBuffer();
		_codec.generateHeader(txn,headers,tdata,eom);

		//auto cback = eom ? bind(&closeWriteCallBack,txn) : &writeCallBack;
		//_down.httpWrite(tdata.data(true),cback);
		if(eom){
			tdata.setFinalTask(newTask((){closeWriteCallBack();txn.onDelayedDestroy();}));
		} 
		_down.httpWrite(tdata);
		

	}

	override size_t sendBody(HTTPTransaction txn,
		in ubyte[] data,
		bool eom)
	{

		auto tdata = new HTTPBuffer();
		size_t rlen = getCodec.generateBody(txn,tdata,data,eom);

		if(eom){
			tdata.setFinalTask(newTask((){closeWriteCallBack();txn.onDelayedDestroy();}));
		} 
		_down.httpWrite(tdata);
		
		// logDebug("send length : ", rlen);
		return rlen;
	}
	
	override size_t sendChunkHeader(HTTPTransaction txn,size_t length)
	{
		auto tdata = new HTTPByteBuffer!Mallocator();
		size_t rlen = getCodec.generateChunkHeader(txn,tdata,length);
		_down.httpWrite(tdata);
		return rlen;
	}

	
	override size_t sendChunkTerminator(HTTPTransaction txn)
	{
		auto tdata = new HTTPByteBuffer!Mallocator();
		size_t rlen = getCodec.generateChunkTerminator(txn,tdata);

		tdata.setFinalTask(newTask((){closeWriteCallBack();txn.onDelayedDestroy();}));
		_down.httpWrite(tdata);

		return rlen;
	}
	

	override size_t sendEOM(HTTPTransaction txn)
	{
		HttpWriteBuffer tdata = new HTTPByteBuffer!Mallocator();
		size_t rlen = getCodec.generateEOM(txn,tdata);
		logDebug("send eom!! ",rlen);
		//if(rlen) 
			//_down.httpWrite(tdata.data(true),bind(&closeWriteCallBack,txn));
		if(rlen){
			tdata.setFinalTask(newTask((){closeWriteCallBack();txn.onDelayedDestroy();}));
			_down.httpWrite(tdata);
		} else {
			_down.post((){
					closeWriteCallBack();
					txn.onDelayedDestroy();
				});
		}
		return rlen;
	}

	//		size_t sendAbort(HTTPTransaction txn,
	//			HTTPErrorCode statusCode);

	override void socketWrite(HTTPTransaction txn,StreamWriteBuffer buffer) {
		_down.httpWrite(buffer);
	}


	override size_t sendWsData(HTTPTransaction txn,OpCode code,ubyte[] data)
	{
		auto tdata = new HTTPByteBuffer!Mallocator();
		size_t rlen = getCodec.generateWsFrame(txn,tdata,code,data);
		if(rlen) {
			bool eom = getCodec.shouldClose();
//			auto cback = eom ? bind(&closeWriteCallBack,txn) : &writeCallBack;
//			_down.httpWrite(tdata.data(true),cback);
			if(eom){
				tdata.setFinalTask(newTask((){closeWriteCallBack();txn.onDelayedDestroy();}));
			} 
			_down.httpWrite(tdata);
		}
		return rlen;
	}

	override void notifyPendingEgress()
	{}
	
	override void detach(HTTPTransaction txn)
	{
		if(_codec)
			_codec.detach(txn);
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

	void restCodeC(HTTPCodec codec){
		if(_codec)
			_codec.setCallback(null);
		codec.setCallback(this);
		_codec = codec;
	}
	
	override bool isDraining(){return false;}
	//HTTPTransaction.Transport, }


	// HTTPCodec.CallBack {
	override void onMessageBegin(HTTPTransaction txn, HTTPMessage msg)
	{
		if(txn){
			txn.transport = this;
		}
		version(CollieDebugMode) logDebug("begin a http requst or reaponse!");
	}

	override void onHeadersComplete(HTTPTransaction txn,
		HTTPMessage msg){
		version(CollieDebugMode) logDebug("url: ", msg.url);
		msg.clientAddress = getPeerAddress();
		setupOnHeadersComplete(txn,msg);
	}

	override void onNativeProtocolUpgrade(HTTPTransaction txn,CodecProtocol protocol,string protocolString,HTTPMessage msg)
	{
        msg.clientAddress = getPeerAddress();
		setupProtocolUpgrade(txn,protocol,protocolString,msg);
	}

	override void onBody(HTTPTransaction txn,const ubyte[] data){
		if(txn)
			txn.onIngressBody(data,cast(ushort)0);
	}

	override void onChunkHeader(HTTPTransaction txn, size_t length){
		if(txn)
			txn.onIngressChunkHeader(length);
	}

	override void onChunkComplete(HTTPTransaction txn){
		if(txn)
			txn.onIngressChunkComplete();
	}

	override void onMessageComplete(HTTPTransaction txn, bool upgrade){
		if(txn)
			txn.onIngressEOM();
	}

	override void onError(HTTPTransaction txn,HTTPErrorCode code){
		logDebug("ERRO : ", code);
		_down.httpClose();
	}

	override void onAbort(HTTPTransaction txn,
		HTTPErrorCode code){
		_down.httpClose();
	}
	
	override void onWsFrame(HTTPTransaction txn,ref WSFrame wsf){
		logDebug(".....");
		if(txn)
			txn.onWsFrame(wsf);
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

	void setupProtocolUpgrade(ref HTTPTransaction txn,CodecProtocol protocol,string protocolString,HTTPMessage msg);

	final void closeWriteCallBack(){
		//txn.onDelayedDestroy();
		if(_codec is null || _codec.shouldClose()) {
			logDebug("\t\t --------do close!!!");
			_down.httpClose();
		}
	}
	
	Address _localAddr;
	Address _peerAddr;
	HTTPCodec _codec;

	HTTPSessionController _controller;
	SessionDown _down;
}

