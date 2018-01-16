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

import kiss.event;
import kiss.net.Timer;
import kiss.net.TcpStreamClient;
import kiss.net.TcpStream;
import collie.net.client.linkinfo;
import collie.net.client.exception;
import kiss.event.task;

@trusted abstract class BaseClient
{
	alias ClientCreatorCallBack = void delegate(TcpStreamClient);
	alias LinkInfo = TLinkInfo!ClientCreatorCallBack;

	this(EventLoop loop) 
	{
		_loop = loop;
	}

	final bool isAlive() @trusted
	{
		return _info.client && _info.client.watched;
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
		_loop.postTask(newTask(&_postConnect));
	}


	final void write(ubyte[] data,TCPWriteCallBack cback = null) @trusted
	{
		write(new WarpStreamBuffer(data,cback));
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
		if(_info.client is null) return;
		_loop.postTask(newTask(&_postClose));
	}

	final @property tcpStreamClient() @trusted {return _info.client;}
	final @property timer() @trusted {return _timer;}
	final @property timeout() @safe {return _timeout;}
	final @property eventLoop() @trusted {return _loop;}
protected:
	void onActive() nothrow;
	void onFailure() nothrow;
	void onClose() nothrow;
	void onRead(in ubyte[] data) nothrow;
	void onTimeout() nothrow;

	final startTimer()
	{
		if(_timeout == 0)
			return;
		if(_timer)
			_timer.stop();
		else {
			_timer = new Timer(_loop);
			_timer.setTimerHandle(&onTimeout);
		}
		_timer.start(_timeout * 1000);
	}
private:
	final void connect()
	{
		_info.client = new TcpStreamClient(_loop);
		if(_info.cback)
			_info.cback(_info.client);
		_info.client.setConnectHandle(&connectCallBack);
		_info.client.setCloseHandle(&doClose);
		_info.client.setReadHandle(&onRead);
		_info.client.connect(_info.addr);
	}

	final void connectCallBack(bool state) nothrow{
		catchAndLogException((){
			if(state){
				_info.cback = null;
				onActive();
			} else {
				_info.client = null;
				if(_info.tryCount < _tryCount){
					_info.tryCount ++;
					connect();
				} else {
					_info.cback = null;
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
		// auto client = _info.client;
		_info.client = null;
		onClose();
		}());
	}

private:
	final void _postClose(){
		if(_info.client)
			_info.client.close();
	}

	final void _postWriteBuffer(StreamWriteBuffer buffer)
    {
        if (_info.client) {
            _info.client.write(buffer);
        } else
            buffer.doFinish();
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

