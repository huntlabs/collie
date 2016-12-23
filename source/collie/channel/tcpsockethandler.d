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
module collie.channel.tcpsockethandler;

import collie.socket;
import collie.channel.handler;
import collie.channel.handlercontext;
import collie.utils.task;

final class TCPSocketHandler : HandlerAdapter!(ubyte[], ubyte[])
{
    this(TCPSocket sock)
    {
		restSocket(sock);
    }

	@property tcpSocket(){return _socket;}

	void restSocket(TCPSocket sock)
	{
		_socket = sock;
		_loop = sock.eventLoop();
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

    override void write(Context ctx, ubyte[] msg, TheCallBack cback)
    {
		if(_loop.isInLoopThread()){
			_postWrite(msg,cback);
		} else {
			_loop.post(newTask(&_postWrite,msg,cback));
		}

    }

    override void close(Context ctx)
    {
		_loop.post(&_postClose);
    }

protected:
    void attachReadCallback()
    {
        _isAttch = true;
        _socket.setReadCallBack(&readCallBack);
        _socket.setCloseCallBack(&closeCallBack);
        context.pipeline.transport(_socket);
    }

    void closeCallBack()
    {
        _isAttch = false;
        context.fireTransportInactive();
        context.pipeline.transport(null);
        _socket.setReadCallBack(null);
        _socket.setCloseCallBack(null);
        _socket = null;
        context.pipeline.deletePipeline();
    }

    void readCallBack(ubyte[] buf)
    {
        context.fireRead(buf);
    }

private:
	final void _postClose(){
		if (_socket)
			_socket.close();
	}
	
	final void _postWrite(ubyte[] msg,TCPWriteCallBack cback)
	{
		if(_socket is null){
			if(cback)
				cback(msg,0);
			return;
		}
		if (context.pipeline.pipelineManager)
			context.pipeline.pipelineManager.refreshTimeout();
		_socket.write(msg, cback);
	}
private:
    bool _isAttch = false;
    TCPSocket _socket;
    EventLoop _loop;
}
