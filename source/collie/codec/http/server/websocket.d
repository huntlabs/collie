/*
 * Collie - An asynchronous event-driven network framework using Dlang development
 *
 * Copyright (C) 2015-2016  Shanghai Putao Technology Co., Ltd 
 *
 * Developer: putao's Dlang team
 *
 * Licensed under the Apache-2.0 License.
 *
 */
module collie.codec.http.server.websocket;

import std.socket;
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


abstract class IWebSocket : HTTPTransactionHandler
{
	alias Buffer = Vector!(ubyte,GCAllocator);
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
	void onErro(HTTPErrorCode code);
    void onText(string frame);
    void onPong(ubyte[] frame);
    void onBinary(ubyte[] frame);

protected:
	override void setTransaction(HTTPTransaction txn) {
		_hand = txn;
	}
	
	override void detachTransaction() {
		_hand = null;
	}
	
	override void onHeadersComplete(HTTPMessage msg) {
	}
	
	override void onBody(const ubyte[] chain) {
	}
	
	override void onChunkHeader(size_t lenght){}
	
	override void onChunkComplete() {}
	
	override void onEOM() {
	}
	
	override void onError(HTTPErrorCode erromsg)  {
	}
	override bool onUpgtade(CodecProtocol protocol,HTTPMessage msg) {
		_addr = msg.clientAddress();
		if(protocol == CodecProtocol.WEBSOCKET)
			return true;
		return false;
	}
	
	override void onWsFrame(ref WSFrame wsf) {
		if(wsf.isControlFrame){
			switch(wsf.opCode){
				case OpCode.OpCodePing:
					sendFarme(OpCode.OpCodePong,wsf.data);
					break;
				case OpCode.OpCodePong:
					onPong(wsf.data);
					break;
				case OpCode.OpCodeClose:
					sendFarme(OpCode.OpCodeClose,wsf.data);
					onClose(wsf.data);
					break;
				default:
					break;
			}
		} else {
			if(wsf.parentCode == OpCode.OpCodeText){
				_text.insertBack(wsf.data);
				gcFree(wsf.data);
				if(wsf.isFinalFrame){
					onText(cast(string)(_text.data(true)));
				}
			} else {
				_binary.insertBack(wsf.data);
				gcFree(wsf.data);
				if(wsf.isFinalFrame){
					onBinary(_text.data(true));
				}
			}
		}
	}
	
	override void onEgressPaused() {}
	
	override void onEgressResumed() {}

	bool sendFarme(OpCode code,ubyte[] data)
	{
		if(!_hand) return false;
		_hand.sendWsData(code,data);
		return true;
	}

package:
	Buffer _text;
	Buffer _binary;
	HTTPTransaction _hand;
    Address _addr;
}
