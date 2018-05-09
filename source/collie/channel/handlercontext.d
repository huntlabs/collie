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
module collie.channel.handlercontext;

import std.conv;
import std.functional;
import kiss.logger;
import collie.channel.pipeline;
import collie.channel.handler;
import collie.channel.exception;
import collie.net;
import kiss.event.socket;

interface HandlerContext(In, Out)
{
    alias HandlerTheCallBack = void delegate(Out, size_t);

    void fireRead(In msg);

    void fireTimeOut();

    void fireTransportActive();
    void fireTransportInactive();

    void fireWrite(Out msg, HandlerTheCallBack cback = null);
    void fireClose();

    @property PipelineBase pipeline();

    @property Channel transport();

}

interface InboundHandlerContext(In)
{
    void fireRead(In msg);
    void fireTimeOut();

    void fireTransportActive();
    void fireTransportInactive();

    @property PipelineBase pipeline();

    @property Channel transport();
}

interface OutboundHandlerContext(Out)
{
	alias OutboundTheCallBack = void delegate(Out, size_t);

    void fireWrite(Out msg, OutboundTheCallBack cback = null);
    void fireClose();

    @property PipelineBase pipeline();

    @property Channel transport();
}

enum HandlerDir
{
    IN,
    OUT,
    BOTH
}

class ContextImplBase(H, Context) : PipelineContext
{
    ~this()
    {
    }

    pragma(inline,true)
    final @property auto handler()
    {
        return _handler;
    }

    pragma(inline,true)
    final void initialize(PipelineBase pipeline, H handler)
    {
        _pipeline = pipeline;
        _handler = handler;
    }

    // PipelineContext overrides

    final override void attachPipeline()
    {
        if (!_attached)
        {
            attachContext(_handler, _impl);
            _handler.attachPipeline(_impl);
            _attached = true;
        }
    }

    final override void detachPipeline()
    {
        _handler.detachPipeline(_impl);
        _attached = false;
        _pipeline = null;
    }

    final override void setNextIn(PipelineContext ctx)
    {
        if (!ctx)
        {
            _nextIn = null;
            return;
        }
        auto nextIn = cast(InboundLink!(H.rout))(ctx);
        if (nextIn)
        {
            _nextIn = nextIn;
        }
        else
        {
			throw new InBoundTypeException("inbound type mismatch after ");
        }
    }

    final override void setNextOut(PipelineContext ctx)
    {
        if (!ctx)
        {
            _nextOut = null;
            return;
        }
        auto nextOut = cast(OutboundLink!(H.wout))(ctx);
        if (nextOut)
        {
            _nextOut = nextOut;
        }
        else
        {
			throw new OutBoundTypeException("outbound type mismatch after ");
        }
    }

    pragma(inline)
    final override HandlerDir getDirection()
    {
        return H.dir;
    }

protected:
    Context _impl;
    PipelineBase _pipeline;
    H _handler;
    InboundLink!(H.rout) _nextIn = null;
    OutboundLink!(H.wout) _nextOut = null;

private:
    bool _attached = false;
}

mixin template CommonContextImpl()
{
    alias Rin = H.rin;
    alias Rout = H.rout;
    alias Win = H.win;
    alias Wout = H.wout;

    this(PipelineBase pipeline, H handler)
    {
        _impl = this;
        initialize(pipeline, handler);
    }

    // For StaticPipeline
    this()
    {
        _impl = this;
    }

    pragma(inline)
    final override @property  Channel transport()
    {
        return _pipeline is null ? null : pipeline.transport();
    }

    pragma(inline)
    final override @property PipelineBase pipeline()
    {
        return _pipeline;
    }
}

mixin template ReadContextImpl()
{

    override void fireRead(Rout msg)
    {
        if (this._nextIn)
        {
            this._nextIn.read(msg);
        }
        else
        {
            logInfo("read reached end of pipeline");
        }
    }

    override void fireTimeOut()
    {
        if (this._nextIn)
        {
            this._nextIn.timeOut();
        }
    }

    override void fireTransportActive()
    {
        if (this._nextIn)
        {
            this._nextIn.transportActive();
        }
    }

    override void fireTransportInactive()
    {
        if (this._nextIn)
        {
            this._nextIn.transportInactive();
        }
    }

    // InboundLink overrides
    override void read(Rin msg)
    {
        _handler.read(this, (msg));
    }

    override void timeOut()
    {
        this._handler.timeOut(this);
    }

    override void transportActive()
    {
        this._handler.transportActive(this);
    }

    override void transportInactive()
    {
        _handler.transportInactive(this);
    }
}

mixin template WriteContextImpl()
{
	alias NextCallBack = void delegate(Wout, size_t);

    pragma(inline)
    override void fireWrite(Wout msg, NextCallBack cback = null)
    {
        if (_nextOut)
        {
            _nextOut.write(msg, cback);
        }
        else
        {
            logInfo("write reached end of pipeline");
			if(cback !is null)
				cback(msg,0);
        }
    }

    pragma(inline)
    override void fireClose()
    {
        if (_nextOut)
        {
            _nextOut.close();
        }
        else
        {
            logInfo("close reached end of pipeline");
        }
    }

    // OutboundLink overrides
	alias ThisCallBack = void delegate(Win, size_t);
    pragma(inline)
    override void write(Win msg, ThisCallBack cback = null)
    {
        _handler.write(this, msg, cback);
    }

    pragma(inline)
    override void close()
    {
        _handler.close(this);
    }

}

final class ContextImpl(H) : ContextImplBase!(H, HandlerContext!(H.rout,
    H.wout)), HandlerContext!(H.rout, H.wout), InboundLink!(H.rin), OutboundLink!(H.win)
{

    static enum dir = HandlerDir.BOTH;

    mixin CommonContextImpl;

    mixin WriteContextImpl;

    mixin ReadContextImpl;

}

final class InboundContextImpl(H) : ContextImplBase!(H,
    InboundHandlerContext!(H.rout)), InboundHandlerContext!(H.rout), InboundLink!(H.rin)
{
    static enum dir = HandlerDir.IN;

    mixin CommonContextImpl;

    mixin ReadContextImpl;

}

final class OutboundContextImpl(H) : ContextImplBase!(H,
    OutboundHandlerContext!(H.wout)), OutboundHandlerContext!(H.wout), OutboundLink!(H.win)
{

    static enum dir = HandlerDir.OUT;

    mixin CommonContextImpl;

    mixin WriteContextImpl;
}

template ContextType(H)
{
    static if (H.dir == HandlerDir.BOTH)
        alias ContextType = ContextImpl!(H);
    else static if (H.dir == HandlerDir.IN)
        alias ContextType = InboundContextImpl!(H);
    else
        alias ContextType = OutboundContextImpl!(H);
}
