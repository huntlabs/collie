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

import collie.net;
import kiss.net.TcpStream;
import collie.net.client.client;

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
		if (th !is null || isAlive)
			return;
		th = new Thread(() { eventLoop.run(); });
		th.start();
	}

	void syncConnet(Address addr)
	{
		if (sem is null)
		{
			sem = new Semaphore(0);
		}
		_sync = true;
		scope (failure)
			_sync = false;
		connect(addr, &onCreate);
		sem.wait();
	}

protected:
	override void onActive() nothrow
	{
		collectException({
			if (_sync)
				sem.notify();
			writeln("Connection succeeded!");
		}());
	}

	override void onFailure() nothrow
	{
		collectException({
			if (_sync)
				sem.notify();
			writeln("Connection failed!");
		}());
	}

	override void onClose() nothrow
	{
		collectException(writeln("Connection closed!"));
	}

	override void onRead(in ubyte[] data) nothrow
	{
		collectException(writeln("received data: ", cast(string) data));
	}

	override void onTimeout(Object sender)
	{
		collectException({
			if (isAlive)
			{
				writeln("Timer ticked!");
				string data = Clock.currTime().toSimpleString();
				write(cast(ubyte[]) data, null);
			}
		}());
	}

	void onCreate(TcpStream client)
	{
		// set client;
		//client.setKeepAlive(1200,2);
		writeln("A tcp client created!");
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
	client.syncConnet(new InternetAddress("127.0.0.1", 8090));
	// client.syncConnet(new InternetAddress("10.1.222.120", 8090));
	//client.eventLoop.run();
	if (!client.isAlive)
	{
		writeln("Connection failed.");
		return;
	}
	while (true)
	{
		writeln("input data to send to server: ");
		string data = readln();
		if (data[$ - 1] == '\n')
			data = data[0 .. $ - 1];
		if (data == "exit" || data == "quit")
		{
			client.close();
			break;
		}
		client.write(cast(ubyte[]) data, null);
	}
}
