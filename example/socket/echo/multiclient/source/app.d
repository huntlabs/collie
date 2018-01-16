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

import kiss.net.TcpStreamClient;
import collie.net;
import collie.net.client.clientmanger;


@trusted class EchoConnect : ClientConnection
{
	this(TcpStreamClient sock, int id){
		super(sock);
		_id = id;
	}
	
protected:
	override void onActive() nothrow
	{
		collectException(writeln(_id," connected suess!"));
	}
	override void onClose() nothrow
	{
		collectException(writeln(_id," client disconnect!"));
	}
	override void onRead(in ubyte[] data) nothrow
	{
		collectException({
				writeln(_id," . read data : ", cast(string)data);
			}());
	}
	
	override void onTimeOut() nothrow
	{
		collectException({
				if(isAlive) {
					writeln(_id," time out do beat!");
					string data = Clock.currTime().toSimpleString();
					write(cast(ubyte[])data,null);
				}
			}());
	}
	int _id;
}

ClientConnection[] clientList;
__gshared _id = 10000;

void main()
{
	ClientConnection newConnect(TcpStreamClient client) @trusted 
	{
		return new EchoConnect(client,++_id);
	}

	void createClient(TcpStreamClient client) @trusted 
	{
		writeln("new client!");
	}

	void newConnection(ClientConnection contion) @trusted 
	{
		writeln("new connection!!");
		clientList ~= contion;
	}
	
	EventLoop loop = new EventLoop();
	
	TCPClientManger manger = new TCPClientManger(loop);
	manger.setNewConnectionCallBack(&newConnect);
	manger.setClientCreatorCallBack(&createClient);
	manger.startTimeout(5);
	manger.tryCout(3);
	foreach(i;0..20){
		manger.connect(new InternetAddress("127.0.0.1",8094),&newConnection);
	}
	
	loop.run();
}