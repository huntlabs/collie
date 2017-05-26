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
module collie.socket.client.client;

import std.socket;

import collie.socket.eventloop;
import collie.socket.timer;
import collie.socket.tcpclient;
import collie.socket.tcpsocket;
import collie.socket.client.linkinfo;
import collie.socket.client.exception;
import collie.utils.task;

@trusted abstract class BaseClient
{
	alias ClientCreatorCallBack = void delegate(TCPClient);
	alias LinkInfo = TLinkInfo!ClientCreatorCallBack;

	this(EventLoop loop) 
	{
		_loop = loop;
	}

	final bool isAlive() @trusted
	{
		return _info.client && _info.client.isAlive;
	}

	final void setTimeout(uint s) @safe
	{
		_timeout = s;
	}

	@property tryCount(){return _tryCount;}
	@property tryCount(uint count){_tryCount = count;}

	final void connect(Address addr,ClientCreatorCallBack cback = null) @trusted
	{
		if(isAlive)
			throw new SocketClientException("must set NewConnection callback ");
		_info.tryCount = 0;
		_info.cback = cback;
		_info.addr = addr;
		_loop.post(&_postConnect);
	}


	final void write(ubyte[] data,TCPWriteCallBack cback = null) @trusted
	{
		if(_loop.isInLoopThread()){
			_postWrite(data,cback);
		} else {
			_loop.post(newTask(&_postWrite,data,cback));
		}
	}

	pragma(inline)
	final void close() @trusted
	{
		if(_info.client is null) return;
		_loop.post(&_postClose);
	}

	final @property tcpClient() @trusted {return _info.client;}
	final @property timer() @trusted {return _timer;}
	final @property timeout() @safe {return _timeout;}
	final @property eventLoop() @trusted {return _loop;}
protected:
	void onActive() nothrow;
	void onFailure() nothrow;
	void onClose() nothrow;
	void onRead(ubyte[] data) nothrow;
	void onTimeout() nothrow;

	final startTimer()
	{
		if(_timeout == 0)
			return;
		if(_timer)
			_timer.stop();
		else {
			_timer = new Timer(_loop);
			_timer.setCallBack(&onTimeout);
		}
		_timer.start(_timeout * 1000);
	}
private:
	final void connect()
	{
		_info.client = new TCPClient(_loop);
		if(_info.cback)
			_info.cback(_info.client);
		_info.client.setConnectCallBack(&connectCallBack);
		_info.client.setCloseCallBack(&doClose);
		_info.client.setReadCallBack(&onRead);
		_info.client.connect(_info.addr);
	}

	final void connectCallBack(bool state){
		if(state){
			_info.cback = null;
			onActive();
		} else {
			import collie.utils.memory;
			gcFree(_info.client);
			_info.client = null;
			if(_info.tryCount < _tryCount){
				_info.tryCount ++;
			} else {
				_info.cback = null;
				if(_timer)
					_timer.stop();
				onFailure();
			}
		}

	}
	final void doClose()
	{
		import collie.utils.memory;
		import collie.utils.task;
		import collie.utils.functional;
		if(_timer)
			_timer.stop();
		auto client = _info.client;
		_loop.post!true(newTask!gcFree(client));
		_info.client = null;
		onClose();
	}

private:
	final void _postClose(){
		if(_info.client)
			_info.client.close();
	}

	pragma(inline)
	final void _postWrite(ubyte[] data,TCPWriteCallBack cback){
		if(_info.client)
			_info.client.write(data, cback);
		else if(cback)
			cback(data,0);
	}

	final void _postConnect(){
		startTimer();
		connect();
	}

private
	EventLoop _loop;
	LinkInfo _info;
	uint _tryCount = 1;
	Timer _timer;
	uint _timeout;
}

