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
import std.experimental.logger;
import std.experimental.allocator.gc_allocator;


import collie.codec.http.httpmessage;
import collie.codec.http.errocode;
import collie.codec.http.codec.wsframe;
import collie.codec.http.headers;
import collie.codec.http.httptansaction;
import collie.codec.http.codec.httpcodec;
import collie.utils.vector;
import collie.utils.memory;
import collie.codec.http.server;


abstract class IWebSocket : RequestHandler
{
	alias Buffer = Vector!(ubyte);
	
	this(){
		_text = Buffer(256);
		_binary= Buffer(256);
	}
	
	pragma(inline)
		final bool ping(ubyte[] data)
	{
		return sendFarme(OpCode.OpCodePing,data);
	}
	
	pragma(inline)
		final bool sendText(string text)
	{
		return sendFarme(OpCode.OpCodeText,cast(ubyte[])text);
	}
	
	pragma(inline)
		final bool sendBinary(ubyte[] data)
	{
		return sendFarme(OpCode.OpCodeBinary,data);
	}
	
	pragma(inline)
		final bool close(ubyte[] data = null)
	{
		return sendFarme(OpCode.OpCodeClose,data);
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
					collectException(sendFarme(OpCode.OpCodePong,wsf.data));
					break;
				case OpCode.OpCodePong:
					collectException(onPong(wsf.data));
					break;
				case OpCode.OpCodeClose:
					collectException((){sendFarme(OpCode.OpCodeClose,wsf.data);
							onClose(wsf.data);}());
					break;
				default:
					break;
			}
		} else {
			if(wsf.parentCode == OpCode.OpCodeText){
				collectException((){_text.insertBack(wsf.data);
				gcFree(wsf.data);
				if(wsf.isFinalFrame){
					onText(cast(string)(_text.data(true)));
				}
					}());
			} else {
				collectException((){_binary.insertBack(wsf.data);
				gcFree(wsf.data);
				if(wsf.isFinalFrame){
					onBinary(_text.data(true));
				}
					}());
			}
		}
	}

	bool sendFarme(OpCode code,ubyte[] data)
	{
		if(!_downstream) return false;
			_downstream.sendWsData(code,data);
		return true;
	}

package:
	Buffer _text;
	Buffer _binary;
    Address _addr;
}
