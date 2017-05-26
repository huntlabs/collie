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
module collie.codec.http.server.requesthandler;

import collie.codec.http.httpmessage;
import collie.codec.http.server.responsehandler;
import collie.codec.http.errocode;
import collie.codec.http.codec.wsframe;
import collie.codec.http.headers;
import collie.codec.http.httptansaction;
import collie.codec.http.server.responsebuilder;
import collie.codec.http.codec.httpcodec;
import collie.utils.string;

abstract class RequestHandler
{
	void setResponseHandler(ResponseHandler handler) nothrow {
		_downstream = handler;
	}

	/**
   * Invoked when we have successfully fetched headers from client. This will
   * always be the first callback invoked on your handler.
   */
	void onResquest(HTTPMessage headers) nothrow;

	/**
   * Invoked when we get part of body for the request.
   */
	void onBody(const ubyte[] data) nothrow;

	/**
   * Invoked when we finish receiving the body.
   */
	void onEOM() nothrow;

	/**
   * Invoked when request processing has been completed and nothing more
   * needs to be done. This may be a good place to log some stats and
   * clean up resources. This is distinct from onEOM() because it is
   * invoked after the response is fully sent. Once this callback has been
   * received, `downstream_` should be considered invalid.
   */
	void requestComplete() nothrow;

	/**
   * Request failed. Maybe because of read/write error on socket or client
   * not being able to send request in time.
   *
   * NOTE: Can be invoked at any time (except for before onRequest).
   *
   * No more callbacks will be invoked after this. You should clean up after
   * yourself.
   */
	void onError(HTTPErrorCode code) nothrow;

	void onFrame(ref WSFrame frame) nothrow
	{}

	bool onUpgtade(CodecProtocol protocol, HTTPMessage msg) nothrow {
		return false;
	}

protected:
	ResponseHandler _downstream;
}

final class RequestHandlerAdaptor : ResponseHandler,HTTPTransactionHandler
{
	this(RequestHandler handler)
	{
		super(handler);
	}
	
	override void setTransaction(HTTPTransaction txn) {
		_txn = txn;
		_upstream.setResponseHandler(this);
	}
	
	override void detachTransaction() {
		_txn = null;
		if(!_erro) {
			_upstream.requestComplete();
		}
	}
	
	override void onHeadersComplete(HTTPMessage msg) {
		trace("onHeadersComplete , erro is : ", _erro , " _upstream is ", cast(void *)_upstream);
		if(msg.getHeaders.exists(HTTPHeaderCode.EXPECT)) {
			trace("has header EXPECT--------");
			string str = msg.getHeaders.getSingleOrEmpty(HTTPHeaderCode.EXPECT);
			if(!isSameIngnoreLowUp(str,"100-continue")) {
				scope HTTPMessage headers = new HTTPMessage();
				headers.constructDirectResponse(1,1,417,"Expectation Failed");
				headers.wantsKeepAlive(false);
				_txn.sendHeadersWithEOM(headers);
				return;
			}else {
				scope HTTPMessage headers = new HTTPMessage();
				headers.constructDirectResponse(1,1,100,"Continue");
				_txn.sendHeaders(headers);
			}
		}
		if(!_erro)
			_upstream.onResquest(msg);
	}
	
	override void onBody(const ubyte[] chain) {
		_upstream.onBody(chain);
	}
	
	override void onChunkHeader(size_t lenght){}
	
	override void onChunkComplete() {}
	
	override void onEOM() {
		if(!_erro)
			_upstream.onEOM();
	}
	
	override void onError(HTTPErrorCode erromsg)  {
		if(_erro) return;
		_erro = true;
		_upstream.onError(erromsg);
	}
	
	override void onWsFrame(ref WSFrame wsf) {
		_upstream.onFrame(wsf);
	}
	
	override void onEgressPaused() {}
	
	override void onEgressResumed() {}
	
	override void sendHeadersWithEOM(HTTPMessage msg) {
		if(_txn)
			_txn.sendHeadersWithEOM(msg);
	}
	
	override void sendHeaders(HTTPMessage msg)
	{
		_responseStarted = true;
		if(_txn)
			_txn.sendHeaders(msg);
	}
	
	override void sendChunkHeader(size_t len){if(_txn)_txn.sendChunkHeader(len);}
	
	override void sendBody(ubyte[] data, bool iseom = false){if(_txn)_txn.sendBody(data,iseom);if(iseom)_responseStarted = false;}
	
	override void sendBody(ref HVector data,bool iseom = false) {if(_txn)_txn.sendBody(data,iseom);if(iseom)_responseStarted = false;}
	
	override void sendChunkTerminator(){if(_txn)_txn.sendChunkTerminator();}
	
	override void sendEOM(){if(_txn)_txn.sendEOM(); _responseStarted = false;}
	
	override void sendTimeOut() {
		if(_txn)
			_txn.sendTimeOut();
	}
	
	override void socketWrite(ubyte[] data,SocketWriteCallBack cback) {
		if(_txn)
			_txn.socketWrite(data,cback);
	}
	
	override void sendWsData(OpCode code,ubyte[] data)
	{
		if(_txn)
			_txn.sendWsData(code,data);
	}
	
	override bool onUpgtade(CodecProtocol protocol,HTTPMessage msg) {
		return _upstream.onUpgtade(protocol, msg);
	}
private:
	HTTPTransaction _txn;
	bool _erro = false;
	bool _responseStarted = false;
}
