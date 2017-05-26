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
module collie.socket.server.connection;

import collie.utils.timingwheel;
import collie.socket.tcpsocket;
import collie.socket.eventloop;
import collie.utils.task;

@trusted abstract class ServerConnection : WheelTimer
{
	this(TCPSocket socket)
	{
		restSocket(socket);
	}

	final void restSocket(TCPSocket socket)
	{
		if(_socket !is null){
			_socket.setCloseCallBack(null);
			_socket.setReadCallBack(null);
			_socket = null;
		}
		if(socket !is null){
			_socket = socket;
			_loop = socket.eventLoop;
			_socket.setCloseCallBack(&doClose);
			_socket.setReadCallBack(&onRead);
		}
	}

	final bool isAlive() @trusted {
		return _socket && _socket.isAlive;
	}

	final bool active() @trusted
	{
		if(_socket is null)
			return false;
		bool active  = _socket.start();
		if(active)
			onActive();
		return active;
	}

	final void write(ubyte[] data,TCPWriteCallBack cback = null) @trusted
	{
		if(_loop.isInLoopThread()){
			_postWrite(data,cback);
		} else {
			_loop.post(newTask(&_postWrite,data,cback));
		}
	}

	final void restTimeout() @trusted
	{
		if(_loop.isInLoopThread()){
			rest();
		} else {
			_loop.post(newTask(&rest,0));
		}
	}
	pragma(inline)
	final void close() @trusted
	{
		_loop.post(&_postClose);
	}

	final @property tcpSocket()@safe {return _socket;}
protected:
	void onActive() nothrow;
	void onClose() nothrow;
	void onRead(ubyte[] data) nothrow;

private:
	final void _postClose(){
		if(_socket)
			_socket.close();
	}

	final void _postWrite(ubyte[] data,TCPWriteCallBack cback)
	{
		if(_socket) {
			rest();
			_socket.write(data, cback);
		}else if(cback)
			cback(data,0);
	}
	final void doClose()
	{
		stop();
		onClose();
	}
private:
	TCPSocket _socket;
	EventLoop _loop;
}

