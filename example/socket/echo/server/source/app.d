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
module app;

import core.thread;

import std.datetime;
import std.stdio;
import std.functional;
import std.exception;
import std.experimental.logger;

import collie.net;
import collie.net.server.connection;
import collie.net.server.tcpserver;

@trusted class EchoConnect : ServerConnection
{
	this(TcpStream sock)
	{
		super(sock);
	}

protected:
	override void onActive() nothrow
	{
		collectException(trace("new client connected : ", tcpStream.remoteAddress.toString()));
	}

	override void onClose() nothrow
	{
		collectException(trace("client disconnect"));
	}

	override void onRead(in ubyte[] data) nothrow
	{
		collectException({
			trace("read data : ", cast(string) data);
			this.write(data.dup);
		}());
	}

	override void onTimeOut() nothrow
	{
		collectException({
			trace("client timeout : ", tcpStream.remoteAddress.toString());
			close();
		}());
	}
}

void main()
{
	@trusted ServerConnection newConnect(EventLoop lop, Socket soc)
	{
		return new EchoConnect(new TcpStream(lop, soc));
	}

	EventLoop loop = new EventLoop();

	TCPServer server = new TCPServer(loop);
	server.setNewConntionCallBack(&newConnect);
	server.startTimeout(120);
	server.bind(new InternetAddress("0.0.0.0", 8096), (TcpListener accept) @trusted{
		accept.reusePort(true);
	});
	server.listen(1024);

	loop.run();
}
