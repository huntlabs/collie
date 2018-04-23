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
module collie.channel.handler;

import std.traits;

import collie.channel.pipeline;
import collie.channel.handlercontext;
import kiss.event.socket;

abstract class HandlerBase(Context)
{

    ~this()
    {
    }

    void attachPipeline(Context /*ctx*/ )
    {
    }

    void detachPipeline(Context /*ctx*/ )
    {
    }

    final @property Context context()
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
/// Rin : the Handle will read type
/// Rout : Next Handle will Read Type
/// Win : the Handle will Write type
/// Wout : Next Handle will write type

abstract class Handler(Rin, Rout = Rin, Win = Rout, Wout = Rin) : HandlerBase!(
    HandlerContext!(Rout, Wout))
{
    alias TheCallBack = void delegate(Win, size_t);
    alias Context = HandlerContext!(Rout, Wout);

    alias rin = Rin;
    alias rout = Rout;
    alias win = Win;
    alias wout = Wout;

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

/// Rin : the Handle will read type
/// Rout : Next Handle will Read Type
abstract class InboundHandler(Rin, Rout = Rin) : HandlerBase!(InboundHandlerContext!Rout)
{
public:
    static enum dir = HandlerDir.IN;

    alias Context = InboundHandlerContext!Rout;
    alias rin = Rin;
    alias rout = Rout;
    alias win = uint;
    alias wout = uint;

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

/// Win : the Handle will Write type
/// Wout : Next Handle will write type
abstract class OutboundHandler(Win, Wout = Win) : HandlerBase!(OutboundHandlerContext!Wout)
{
public:
    static enum dir = HandlerDir.OUT;

    alias Context = OutboundHandlerContext!Wout;
    alias OutboundHandlerCallBack = void delegate(Win, size_t);

    alias rin = uint;
    alias rout = uint;
    alias win = Win;
    alias wout = Wout;

    void write(Context ctx, Win msg, OutboundHandlerCallBack cback = null);

    void close(Context ctx)
    {
        return ctx.fireClose();
    }
}

class HandlerAdapter(R, W = R) : Handler!(R, R, W, W)
{
    alias Context = Handler!(R, R, W, W).Context;
    alias TheCallBack = Handler!(R, R, W, W).TheCallBack;

    override void read(Context ctx, R msg)
    {
        ctx.fireRead((msg));
    }

    override void write(Context ctx, W msg, TheCallBack cback)
    {
        ctx.fireWrite(msg, cback);
    }
}

abstract class PipelineContext
{
public:
     ~this()
    {
        //   writeln("PipelineContext ~ this");
    }

    void attachPipeline();
    void detachPipeline();

    pragma(inline)
    final void attachContext(H, HandlerContext)(H handler, HandlerContext ctx)
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
    void read(In msg);
    void timeOut();
    void transportActive();
    void transportInactive();
}

interface OutboundLink(Out)
{
    alias OutboundLinkCallBack = void delegate(Out, size_t);
    void write(Out msg, OutboundLinkCallBack cback = null);
    void close();
}
