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
module collie.net.server.connection;

import kiss.net.TcpStream;
import kiss.timingwheel;
import kiss.net.Timer;
import kiss.event;
import kiss.event.task;
import kiss.log;


abstract class ServerConnection : WheelTimer
{
	this(TcpStream socket)
	{
		restSocket(socket);
	}

	final void restSocket(TcpStream socket)
	{
		if(_socket !is null){
			_socket.setCloseHandle(null);
			_socket.setReadHandle(null);
			_socket = null;
		}
		if(socket !is null){
			_socket = socket;
			_loop = cast(EventLoop) socket.eventLoop;
			_socket.onClosed(&doClose);
			_socket.setReadHandle(&onRead);
		}
	}

	final bool isAlive() @trusted {
		return _socket && _socket.watched;
	}

	final bool active() @trusted
	{
		if(_socket is null)
			return false;
		bool active  = _socket.watch;
		if(active)
			onActive();
		return active;
	}

	final void write(ubyte[] data,TCPWriteCallBack cback = null) @trusted
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

	final void restTimeout() @trusted
	{
		if(_loop.isInLoopThread()){
			rest();
		} else {
			_loop.postTask(newTask(&rest,0));
		}
	}
	pragma(inline)
	final void close() @trusted
	{
		_loop.postTask(newTask(&_postClose));
	}

	final @property tcpStream()@safe {return _socket;}
protected:
	void onActive() nothrow;
	void onClose() nothrow;
	void onRead(in ubyte[] data) nothrow;

private:
	final void _postClose(){
		if(_socket)
			_socket.close();
	}

 	final void _postWriteBuffer(StreamWriteBuffer buffer)
    {
        if (_socket) {
		debug logDebug("posting data...  ");
            rest();
            _socket.write(buffer);
        } else
		{
			debug logDebug("post done.");
            buffer.doFinish();
		}
    }

	final void doClose() 
	{
		stop();
		onClose();
	}
private:
	TcpStream _socket;
	EventLoop _loop;
}

