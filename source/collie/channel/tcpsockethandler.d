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

final class TCPSocketHandler : HandlerAdapter!(ubyte[], ubyte[])
{
    //alias TheCallBack = void delegate(ubyte[],uint);
    //alias HandleContext!(UniqueBuffer, ubyte[]) Context;

    this(TCPSocket sock)
    {
        _socket = sock;
        _loop = sock.eventLoop();
    }

    ~this()
    {
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
        _loop.post(delegate(){
            if(_socket is null)
            {
                cback(msg,0);
                return;
            }
            if (context.pipeline.pipelineManager)
                        context.pipeline.pipelineManager.refreshTimeout();
            _socket.write(msg, cback);
        });

    }

    override void close(Context ctx)
    {
        _loop.post(delegate(){
            if (_socket)
                _socket.close();
        });
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
    bool _isAttch = false;
    TCPSocket _socket;
    EventLoop _loop;
}
