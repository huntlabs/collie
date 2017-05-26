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
module collie.codec.http.session.httpupstreamsession;

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
		errnoEnforce(handle,"handle is null !");
		txn.handler(handle);
		txn.onIngressHeadersComplete(msg);

	}
	
	override void setupProtocolUpgrade(ref HTTPTransaction txn,CodecProtocol protocol,string protocolString,HTTPMessage msg) {
		//restCodeC(new WebsocketCodec(TransportDirection.UPSTREAM));
	}
}
