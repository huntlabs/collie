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
module collie.channel.tcpsockethandler;

import collie.net;
import collie.channel.handler;
import collie.channel.handlercontext;
import kiss.net;
import kiss.exception;
import kiss.net.TcpStream;
import kiss.event.task;

final @trusted class TCPSocketHandler : HandlerAdapter!(const(ubyte[]), StreamWriteBuffer)
{
    this(TcpStream sock)
    {
		restSocket(sock);
    }

	@property tcpSocket(){return _socket;}

	void restSocket(TcpStream sock)
	{
		_socket = sock;
		_loop = cast(EventLoop) sock.eventLoop();
	}

    override void transportActive(Context ctx)
    {
        attachReadCallback();
        _socket.start();
        ctx.fireTransportActive();
    }

    override void transportInactive(Context ctx)
    {
        if (_isAttch && _socket) {
            _socket.close();
		} else {
        	ctx.fireTransportInactive();
		}
    }

    override void write(Context ctx, StreamWriteBuffer buffer, TheCallBack cback = null)
    {
		if(_loop.isInLoopThread()){
			_postWrite(buffer);
		} else {
			_loop.postTask(newTask(&_postWrite,buffer));
		}

    }

    override void close(Context ctx)
    {
		_loop.postTask(newTask(&_postClose));
    }

protected:
    void attachReadCallback()
    {
        _isAttch = true;
        _socket.onDataReceived(&readCallBack);
        _socket.onClosed(&closeCallBack);
        context.pipeline.transport(_socket);
    }

    void closeCallBack() nothrow
    {
        _isAttch = false;
        catchAndLogException((){
            context.fireTransportInactive();
            context.pipeline.transport(null);
            _socket.onDataReceived(null);
            _socket.onClosed(null);
            _socket = null;
            context.pipeline.deletePipeline();
        }());
    }

    void readCallBack(in ubyte[] buf) nothrow
    {
        catchAndLogException(
            context.fireRead(buf)
        );
    }

private:
	final void _postClose(){
		if (_socket)
			_socket.close();
	}
	
	final void _postWrite(StreamWriteBuffer buffer)
	{
		if(_socket is null){
			buffer.doFinish();
			return;
		}
		if (context.pipeline.pipelineManager)
			context.pipeline.pipelineManager.refreshTimeout();
		_socket.write(buffer);
	}
private:
    bool _isAttch = false;
    TcpStream _socket;
    EventLoop _loop;
}
