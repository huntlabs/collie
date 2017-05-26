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
module collie.codec.http.session.sessiondown;

import collie.channel;
import collie.codec.http.session.httpsession;
import std.socket;
import collie.socket.tcpsocket;
import collie.socket.eventloop;
import collie.utils.task;
import collie.utils.memory;

@trusted class PipelineSessionDown : HandlerAdapter!(ubyte[]),SessionDown
{
	@property httpSession(){return _session;}
	@property httpSession(HTTPSession session){_session = session;}

	override void timeOut(Context ctx) {
		if(_session)
			_session.onTimeout();
	}

	override void transportActive(Context ctx) {
		TCPSocket sock = cast(TCPSocket)context.pipeline.transport;
		_local = sock.localAddress;
		_remote = sock.remoteAddress;
		_loop = sock.eventLoop();
		if(_session)
			_session.onActive();
	}

	override void transportInactive(Context ctx) {
		if(_session)
			_session.inActive();
	}

	override void read(Context ctx,ubyte[] msg) {
		if(_session)
			_session.onRead(msg);
	}

	override void httpClose() {
		close(context);
	}

	override void httpWrite(ubyte[] data,void delegate(ubyte[], size_t) cback) {
		write(context,data,cback);
	}

	override Address localAddress() {
		return _local;
	}

	override Address remoteAddress() {
		return _remote;
	}

	override  void post(void delegate() call){
		_loop.post(call);
	}

private:
	HTTPSession _session;
	Address _local;
	Address _remote;
	EventLoop _loop;
}


import collie.socket.server.tcpserver;
import collie.socket.server.connection;
import std.exception;

@trusted class HTTPConnection : ServerConnection,SessionDown
{
	this(TCPSocket sock)
	{
		super(sock);
		_loop = sock.eventLoop();
	}

	@property httpSession(){return _session;}
	@property httpSession(HTTPSession session){_session = session;}

	override void httpClose() {
		close();
	}
	override void httpWrite(ubyte[] data,void delegate(ubyte[], size_t) cback) {
		write(data,cback);
	}
	override Address localAddress() {
		return tcpSocket.localAddress;
	}

	override Address remoteAddress() {
		return tcpSocket.remoteAddress;
	}

	override  void post(void delegate() call){
		_loop.post(call);
	}
protected:
	override void onTimeOut() nothrow {
		if(_session)
			collectException(_session.onTimeout());
	}

	override void onClose() nothrow {
		if(_session)
			collectException(_session.inActive());
//		auto sock = tcpSocket();
//		if(sock)
//			collectException(_loop.post!true(newTask!gcFree(sock)));
	}

	override  void onActive() nothrow {
		if(_session)
			collectException(_session.onActive());
	}

	override  void onRead(ubyte[] data) nothrow {
		if(_session)
			collectException(_session.onRead(data));
	}


private:
	HTTPSession _session;
	EventLoop _loop;
}