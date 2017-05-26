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
module collie.codec.http.session.httpdownstreamsession;

import std.exception;

import collie.codec.http.session.httpsession;
import collie.codec.http.headers;
import collie.codec.http.codec.wsframe;
import collie.codec.http.httpmessage;
import collie.codec.http.httptansaction;
import collie.codec.http.codec.httpcodec;
import std.base64;
import std.digest.sha;
import collie.codec.http.codec.websocketcodec;

final class HTTPDownstreamSession : HTTPSession
{
	this(HTTPSessionController controller,HTTPCodec codec, SessionDown down)
	{
		super(controller,codec,down);
	}

protected:
	override void setupOnHeadersComplete(ref HTTPTransaction txn,
		HTTPMessage msg)
	{
		auto handle =  _controller.getRequestHandler(txn,msg);
		if(handle is null)
		{
			try{
				enum string _404 = "<h1>Not Found!</h1><p>the http RequestHandle is null!</p>";
				import collie.codec.http.headers;
				import std.typecons;
				import std.conv;
				scope HTTPMessage rmsg = new HTTPMessage();
				rmsg.statusCode = 404;
				rmsg.statusMessage = HTTPMessage.statusText(404);
				rmsg.getHeaders.add(HTTPHeaderCode.CONNECTION,"close");
				rmsg.getHeaders.add(HTTPHeaderCode.CONTENT_LENGTH,to!string(_404.length));
				sendHeaders(txn,rmsg,false);
				sendBody(txn,cast(ubyte[])_404,true);
				txn = null;
			} catch (Exception e){
				import collie.utils.exception;
				showException(e);
			}
		} else {
			txn.handler(handle);
			txn.onIngressHeadersComplete(msg);
		}
	}

	override void setupProtocolUpgrade(ref HTTPTransaction txn,CodecProtocol protocol,string protocolString,HTTPMessage msg) {
		void doErro(){
			scope HTTPMessage rmsg = new HTTPMessage();
			rmsg.statusCode = 400;
			rmsg.statusMessage = HTTPMessage.statusText(400);
			rmsg.getHeaders.add(HTTPHeaderCode.CONNECTION,"close");
			sendHeaders(txn,rmsg,true);
		}
		auto handle =  _controller.getRequestHandler(txn,msg);
		if(handle is null){
			collectException( doErro());
			return;
		}
		txn.handler(handle);
		if(protocol == CodecProtocol.init || !txn.onUpgtade(protocol, msg))
		{
			collectException( doErro());
			return;
		}
		bool rv = true;
		switch(protocol){
			case CodecProtocol.WEBSOCKET :
				rv = doUpgradeWebSocket(txn,msg);
				break;
			default :
				rv = false;
				break;
		}
		if(!rv)
			doErro();
	}

	bool doUpgradeWebSocket(ref HTTPTransaction txn,HTTPMessage msg)
	{
		string key = msg.getHeaders.getSingleOrEmpty(HTTPHeaderCode.SEC_WEBSOCKET_KEY);
		string ver = msg.getHeaders.getSingleOrEmpty(HTTPHeaderCode.SEC_WEBSOCKET_VERSION);
		if(ver != "13") 
			return false;
		auto accept = cast(string) Base64.encode(sha1Of(key ~ WebSocketGuid));

		scope HTTPMessage rmsg = new HTTPMessage();
		rmsg.statusCode = 101;
		rmsg.statusMessage = HTTPMessage.statusText(101);
		rmsg.getHeaders.add(HTTPHeaderCode.CONNECTION,"keep-alive");
		rmsg.getHeaders.add(HTTPHeaderCode.SEC_WEBSOCKET_ACCEPT,accept);
		rmsg.getHeaders.add(HTTPHeaderCode.CONNECTION,"Upgrade");
		rmsg.getHeaders.add(HTTPHeaderCode.UPGRADE,"websocket");
		sendHeaders(txn,rmsg,false);
		restCodeC(new WebsocketCodec(TransportDirection.DOWNSTREAM,txn));
		return true;
	}

}


