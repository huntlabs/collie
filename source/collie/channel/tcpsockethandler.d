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
        if(_socket)
            _socket.close();
    }

    override void write(Context ctx, ubyte[] msg, TheCallBack cback)
    {
        if(context.pipeline.pipelineManager)
            context.pipeline.pipelineManager.refreshTimeout();
       if(_socket) _socket.write(msg, cback);
    }

    override void close(Context ctx)
    {
        if(_socket)
            _socket.close();
    }

protected:
    void attachReadCallback()
    {
        _socket.setReadCallBack(&readCallBack);
        _socket.setCloseCallBack(&closeCallBack);
        context.pipeline.transport(_socket);
    }

    void closeCallBack()
    {
        context.fireTransportInactive();
        context.pipeline.deletePipeline();
        context.pipeline.transport(null);
        _socket = null;
        
    }

    void readCallBack(ubyte[] buf)
    {
        context.fireRead(buf);
    }

private:
    TCPSocket _socket;
}
