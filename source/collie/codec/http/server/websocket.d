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
module collie.codec.http.server.websocket;

import std.socket;
import std.exception;

import std.experimental.allocator.gc_allocator;


import collie.codec.http.httpmessage;
import collie.codec.http.errocode;
import collie.codec.http.codec.wsframe;
import collie.codec.http.headers;
import collie.codec.http.httptansaction;
import collie.codec.http.codec.httpcodec;
import kiss.container.Vector;
import collie.utils.memory;
import collie.codec.http.server;


abstract class IWebSocket : RequestHandler
{	
	this(){
	}
	
	pragma(inline)
		final bool ping(ubyte[] data)
	{
		return sendFrame(OpCode.OpCodePing,data);
	}
	
	pragma(inline)
		final bool sendText(string text)
	{
		return sendFrame(OpCode.OpCodeText,cast(ubyte[])text);
	}
	
	pragma(inline)
		final bool sendBinary(ubyte[] data)
	{
		return sendFrame(OpCode.OpCodeBinary,data);
	}
	
	pragma(inline)
		final bool close(ubyte[] data = null)
	{
		return sendFrame(OpCode.OpCodeClose,data);
	}
	
	pragma(inline,true)
		final @property Address remoteAdress()
	{
		return _addr;
	}

    void onClose(ubyte[] data);
    void onText(string frame);
    void onPong(ubyte[] frame);
    void onBinary(ubyte[] frame);
	void onErro(HTTPErrorCode code);
protected:
	final override void onResquest(HTTPMessage headers) nothrow{}
	final override void onBody(const ubyte[] data) nothrow{}
	final override void onEOM() nothrow{}
	final override void requestComplete() nothrow{}
	final override void onError(HTTPErrorCode code) nothrow {
        if(code != HTTPErrorCode.TIME_OUT)
		    _downstream = null;
		collectException(onErro(code));
	}
	override bool onUpgtade(CodecProtocol protocol,HTTPMessage msg) nothrow{
		//_addr = msg.clientAddress();
		collectException(msg.clientAddress(),_addr);
		if(protocol == CodecProtocol.WEBSOCKET)
			return true;
		return false;
	}
	
	override void onFrame(ref WSFrame wsf) nothrow{
		if(wsf.isControlFrame){
			switch(wsf.opCode){
				case OpCode.OpCodePing:
					collectException(sendFrame(OpCode.OpCodePong,wsf.data));
					break;
				case OpCode.OpCodePong:
					collectException(onPong(wsf.data));
					break;
				case OpCode.OpCodeClose:
					collectException((){sendFrame(OpCode.OpCodeClose,wsf.data);
							onClose(wsf.data);}());
					break;
				default:
					break;
			}
		} else {
			if(wsf.parentCode == OpCode.OpCodeText){
				collectException((){
					_text ~= wsf.data;
					if(wsf.isFinalFrame){
						onText(cast(string)(_text));
						_text = null;
					}
					}());
			} else {
				collectException((){
					_binary ~= wsf.data;
					if(wsf.isFinalFrame){
						onBinary(_binary);
						_binary = null;
					}
					}());
			}
		}
	}

	bool sendFrame(OpCode code,ubyte[] data)
	{
		if(!_downstream) return false;
			_downstream.sendWsData(code,data);
		return true;
	}

	deprecated("Incorrect spelling. Using sendFrame instead.")
 	bool sendFarme(OpCode code,ubyte[] data)
 	{
		return sendFrame(code, data);
	}

package:
	ubyte[] _text;
	ubyte[] _binary;
    Address _addr;
}
