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

import collie.socket;
import collie.socket.client.client;

import core.thread;
import core.sync.semaphore;


@trusted class MyClient : BaseClient
{
	this()
	{
		super(new EventLoop());
	}

	void runInThread()
	{
		if(th !is null || isAlive)
			return;
		th = new Thread((){eventLoop.run();});
		th.start();
	}

	void syncConnet(Address addr)
	{
		if(sem is null){
			sem = new Semaphore(0);
		}
		_sync = true;
		scope(failure)_sync = false;
		connect(addr,&onCreate);
		sem.wait();
	}

protected:
	override void onActive() nothrow {
		collectException({
				if(_sync)
					sem.notify();
				writeln("connect suess!");
			}());
	}

	override void onFailure() nothrow
	{
		collectException({
				if(_sync)
					sem.notify();
				writeln("connect failure!");
			}());
	}

	override void onClose() nothrow {
		collectException(writeln("connect close!"));
	}

	override void onRead(ubyte[] data) nothrow {
		collectException(writeln("read data : ", cast(string)data));
	}

	override void onTimeout() nothrow {
		collectException({
				if(isAlive) {
					writeln("time out do beat!");
					string data = Clock.currTime().toSimpleString();
					write(cast(ubyte[])data,null);
				}
			}());
	}

	void onCreate(TCPClient client)
	{
		// set client;
		client.setKeepAlive(1200,2);
		writeln("create a tcp client!");
	}
private:

	Thread th;
	Semaphore sem;
	bool _sync = false;
}


void main()
{
	MyClient client = new MyClient();
	client.runInThread();
	client.setTimeout(60);
	client.tryCount(3);
	client.syncConnet(new InternetAddress("127.0.0.1",8094));
	//client.connect(new InternetAddress("127.0.0.1",8094));
	//client.eventLoop.run();
	if(!client.isAlive){
		return;
	}
	while(true)
	{
		writeln("write to send server: ");
		string data = readln();
		client.write(cast(ubyte[])data,null);
	}
}
