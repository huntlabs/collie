module collie.channel.handler;

import std.traits;
import std.functional;

import collie.channel.pipeline;
import collie.channel.handlercontext;

template isClassOrInterface(T)
{
    enum isClassOrInterface = (is(T == class) || is(T == interface));
}

abstract class HandlerBase(Context)
{
    void attachPipeline(Context /*ctx*/ )
    {
    }

    void detachPipeline(Context /*ctx*/ )
    {
    }

    Context getContext()
    {
        if (_attachCount != 1)
        {
            return null;
        }
        assert(_ctx);
        return _ctx;
    }

protected:
    ulong _attachCount = 0;
    Context _ctx;
}

abstract class Handler(Rin, Rout = Rin, Win = Rout, Wout = Rin) : HandlerBase!(
    HandlerContext!(Rout, Wout))
{
    alias TheCallBack = void delegate(Win, uint);
    alias HandlerContext!(Rout, Wout) Context;

    alias Rin rin;
    alias Rout rout;
    alias Win win;
    alias Wout wout;

    static enum dir = HandlerDir.BOTH;

    void read(Context ctx, Rin msg);

    void timeOut(Context ctx)
    {
        ctx.fireTimeOut();
    }

    void transportActive(Context ctx)
    {
        ctx.fireTransportActive();
    }

    void transportInactive(Context ctx)
    {
        ctx.fireTransportInactive();
    }

    void write(Context ctx, Win msg, TheCallBack cback = null);
    void close(Context ctx)
    {
        ctx.fireClose();
    }
}

abstract class InboundHandler(Rin, Rout = Rin) : HandlerBase!(InboundHandlerContext!Rout)
{
public:
    static enum dir = HandlerDir.IN;

    alias InboundHandlerContext!Rout Context;
    alias Rin rin;
    alias Rout rout;
    alias uint win;
    alias uint wout;

    void read(Context ctx, Rin msg);

    void timeOut(Context ctx)
    {
        ctx.fireTimeOut();
    }

    void transportActive(Context ctx)
    {
        ctx.fireTransportActive();
    }

    void transportInactive(Context ctx)
    {
        ctx.fireTransportInactive();
    }

}

abstract class OutboundHandler(Win, Wout = Win) : HandlerBase!(OutboundHandlerContext!Wout)
{
public:
    static enum dir = HandlerDir.OUT;

    alias OutboundHandlerContext!Wout Context;
    alias TheCallBack = void delegate(Win, uint);

    alias uint rin;
    alias uint rout;
    alias Win win;
    alias Wout wout;

    void write(Context ctx, Win msg, TheCallBack cback = null);

    void close(Context ctx)
    {
        return ctx.fireClose();
    }
}

class HandlerAdapter(R, W = R) : Handler!(R, R, W, W)
{
    alias Handler!(R, R, W, W).Context Context;
    alias Handler!(R, R, W, W).TheCallBack TheCallBack;

    override void read(Context ctx, R msg)
    {
        ctx.fireRead(forward!(msg));
    }

    override void write(Context ctx, W msg, TheCallBack cback)
    {
        return ctx.fireWrite(forward!(msg, cback));
    }
}

abstract class PipelineContext
{
public:

    void attachPipeline();
    void detachPipeline();

    void attachContext(H, HandlerContext)(H handler, HandlerContext ctx)
    {
        if (++handler._attachCount == 1)
        {
            handler._ctx = ctx;
        }
        else
        {
            handler._ctx = null;
        }
    }

    void setNextIn(PipelineContext ctx);
    void setNextOut(PipelineContext ctx);

    HandlerDir getDirection();
}

package:

interface InboundLink(In)
{
public:
    void read(In msg);
    void timeOut();
    void transportActive();
    void transportInactive();
}

interface OutboundLink(Out)
{
public:
    alias TheCallBack = void delegate(Out, uint);
    void write(Out msg, TheCallBack cback = null);
    void close();
};
