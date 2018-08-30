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
import collie.net;
import collie.utils.memory;
import std.socket;
import kiss.net.TcpStream;
import kiss.event.task;
import kiss.logger;

@trusted class PipelineSessionDown : HandlerAdapter!(const(ubyte[]), StreamWriteBuffer),SessionDown
{
	@property httpSession(){return _session;}
	@property httpSession(HTTPSession session){_session = session;}

	override void timeOut(Context ctx) {
		if(_session)
			_session.onTimeout();
	}

	override void transportActive(Context ctx) {
		TcpStream sock = cast(TcpStream)context.pipeline.transport;
		_local = sock.localAddress;
		_remote = sock.remoteAddress;
		_loop = cast(EventLoop) sock.eventLoop();
		if(_session)
			_session.onActive();
	}

	override void transportInactive(Context ctx) {
		if(_session)
			_session.inActive();
	}

	override void read(Context ctx,const(ubyte[]) msg) {
		if(_session)
			_session.onRead(cast(ubyte[])msg);
	}

	override void httpClose() {
		close(context);
	}

	override void httpWrite(StreamWriteBuffer buffer) {
		write(context,buffer,null);
	}

	override Address localAddress() {
		return _local;
	}

	override Address remoteAddress() {
		return _remote;
	}

	override  void post(void delegate() call){
		_loop.postTask(newTask(call));
	}

private:
	HTTPSession _session;
	Address _local;
	Address _remote;
	EventLoop _loop;
}


import collie.net.server.tcpserver;
import collie.net.server.connection;
import std.exception;

@trusted class HTTPConnection : ServerConnection,SessionDown
{
	this(TcpStream sock)
	{
		super(sock);
		_loop = cast(EventLoop)sock.eventLoop();
	}

	@property httpSession(){return _session;}
	@property httpSession(HTTPSession session){_session = session;}

	override void httpClose() {
		close();
	}
	override void httpWrite(StreamWriteBuffer data) {
		write(data); 
	}
	override Address localAddress() {
		assert(tcpStream !is null);
		return tcpStream.localAddress;
	}

	override Address remoteAddress() {
		assert(tcpStream !is null);
		return tcpStream.remoteAddress;
	}

	override  void post(void delegate() call){
		_loop.postTask(newTask(call));
	}
protected:
	override void onTimeOut() nothrow {
		if(_session) {
			try {
				version(CollieDebugMode) warning("timeout");
				_session.onTimeout();
			} catch(Exception) {}
		}
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

	override  void onRead(in ubyte[] data) nothrow {
		if(_session)
			collectException(_session.onRead(cast(ubyte[])data));
	}


private:
	HTTPSession _session;
	EventLoop _loop;
}