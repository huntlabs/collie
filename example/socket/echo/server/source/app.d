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
	this(TcpStream sock){
		super(sock);
	}

protected:
	override void onActive() nothrow
	{
		collectException(writeln("new client connected : ",tcpStream.remoteAddress.toString()));
	}

	override void onClose() nothrow
	{
		collectException(writeln("client disconnect"));
	}

	override void onRead(in ubyte[] data) nothrow
	{
		collectException({
				writeln("read data : ", cast(string)data);
				this.write(data.dup);
			}());
	}

	override void onTimeOut() nothrow
	{
		collectException({
				writeln("client timeout : ",tcpStream.remoteAddress.toString());
				close();
			}());
	}
}

void main()
{
	@trusted ServerConnection newConnect(EventLoop lop,Socket soc)
	{
		return new EchoConnect(new TcpStream(lop,soc));
	}

	EventLoop loop = new EventLoop();

	TCPServer server = new TCPServer(loop);
	server.setNewConntionCallBack(&newConnect);
	server.startTimeout(120);
	server.bind(new InternetAddress("127.0.0.1",8094),(TcpListener accept){
			accept.reusePort(true);
		});
	server.listen(1024);

	loop.run();
}
