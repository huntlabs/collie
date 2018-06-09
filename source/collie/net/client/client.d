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
module collie.net.client.client;

import std.socket;

import kiss.exception;
import kiss.event;
import kiss.util.timer;
import kiss.net.TcpStream;
import kiss.net.TcpStream;
import collie.net.client.linklogInfo;
import collie.net.client.exception;
import kiss.event.task;

@trusted abstract class BaseClient
{
	alias ClientCreatorCallBack = void delegate(TcpStream);
	alias LinklogInfo = TLinklogInfo!ClientCreatorCallBack;

	this(EventLoop loop) 
	{
		_loop = loop;
	}

	final bool isAlive() @trusted
	{
		return _logInfo.client && _logInfo.client.isRegistered;
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
		_logInfo.tryCount = 0;
		_logInfo.cback = cback;
		_logInfo.addr = addr;
		_loop.postTask(newTask(&_postConnect));
	}


	final void write(ubyte[] data, DataWrittenHandler cback = null) @trusted
	{
		write(new SocketStreamBuffer(data,cback));
	}

    final void write(StreamWriteBuffer buffer) @trusted
    {
        if (_loop.isInLoopThread()) {
            _postWriteBuffer(buffer);
        } else {
            _loop.postTask(newTask(&_postWriteBuffer, buffer));
        }
    }

	pragma(inline)
	final void close() @trusted
	{
		if(_logInfo.client is null) return;
		_loop.postTask(newTask(&_postClose));
	}

	final @property TcpStream tcpStreamClient() @trusted {return _logInfo.client;}
	final @property KissTimer timer() @trusted {return _timer;}
	final @property uint timeout() @safe {return _timeout;}
	final @property EventLoop eventLoop() @trusted {return _loop;}
protected:
	void onActive() nothrow;
	void onFailure() nothrow;
	void onClose() nothrow;
	void onRead(in ubyte[] data) nothrow;
	void onTimeout(Object sender);

	final startTimer()
	{
		if(_timeout == 0)
			return;
		if(_timer)
			_timer.stop();
		else {
			_timer = new KissTimer(_loop);
			_timer.onTick(&onTimeout);
		}
		_timer.interval = _timeout * 1000;
		_timer.start();
	}
private:
	final void connect()
	{
		TcpStream stream = new TcpStream(_loop);
		_logInfo.client = stream;
		if(_logInfo.cback)
			_logInfo.cback(stream);
		stream.onConnected(&connectCallBack);
		stream.onClosed(&doClose);
		stream.onDataReceived(&onRead);
		stream.connect(_logInfo.addr);
	}

	final void connectCallBack(bool state) nothrow{
		catchAndLogException((){
			if(state){
				_logInfo.cback = null;
				onActive();
			} else {
				_logInfo.client = null;
				if(_logInfo.tryCount < _tryCount){
					_logInfo.tryCount ++;
					connect();
				} else {
					_logInfo.cback = null;
					if(_timer)
						_timer.stop();
					onFailure();
				}
			}
		}());

	}
	final void doClose() nothrow
	{
		catchAndLogException((){
		if(_timer)
			_timer.stop();
		// auto client = _logInfo.client;
		_logInfo.client = null;
		onClose();
		}());
	}

private:
	final void _postClose(){
		if(_logInfo.client)
			_logInfo.client.close();
	}

	final void _postWriteBuffer(StreamWriteBuffer buffer)
    {
        if (_logInfo.client) {
            _logInfo.client.write(buffer);
        } else
            buffer.doFinish();
    }
	
	final void _postConnect(){
		startTimer();
		connect();
	}

private
	EventLoop _loop;
	LinklogInfo _logInfo;
	uint _tryCount = 1;
	KissTimer _timer;
	uint _timeout;
}

