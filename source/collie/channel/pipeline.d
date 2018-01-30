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
module collie.channel.pipeline;

import std.typecons;
import std.variant;
import std.functional;
import std.range.primitives;

import collie.channel.handler;
import collie.channel.handlercontext;
import collie.channel.exception;
import collie.net;
import kiss.event;

interface PipelineManager
{
    void deletePipeline(PipelineBase pipeline);
    void refreshTimeout();
}

abstract class PipelineBase
{
    this()
    {
    }

    ~this()
    {
    }

    pragma(inline)
    @property final void pipelineManager(PipelineManager manager)
    {
        _manager = manager;
    }

    pragma(inline,true)
    @property final PipelineManager pipelineManager()
    {
        return _manager;
    }

    pragma(inline)
    final void deletePipeline()
    {
        if (_manager)
        {
            _manager.deletePipeline(this);
        }
    }

    pragma(inline)
    @property final void transport(BaseTransport transport)
    {
        _transport = transport;
    }

    pragma(inline,true)
    @property final transport()
    {
        return _transport;
    }

    pragma(inline)
    final PipelineBase addBack(H)(H handler)
    {
        return addHelper(new ContextType!(H)(this, handler), false);
    }

    pragma(inline)
    final PipelineBase addFront(H)(H handler)
    {
        return addHelper(new ContextType!(H)(this, handler), true);
    }

    pragma(inline)
    final PipelineBase remove(H)(H handler)
    {
        return removeHelper!H(handler, true);
    }

    pragma(inline)
    final PipelineBase remove(H)()
    {
        return removeHelper!H(null, false);
    }

    pragma(inline)
    final PipelineBase removeFront()
    {
        if (_ctxs.empty())
        {
			throw new PipelineEmptyException("No handlers in pipeline");
        }
        removeAt(0);
        return this;
    }

    pragma(inline)
    final PipelineBase removeBack()
    {
        if (_ctxs.empty())
        {
			throw new PipelineEmptyException("No handlers in pipeline");
        }
        removeAt(_ctxs.length - 1);
        return this;
    }

    pragma(inline)
    final auto getHandler(H)(int i)
    {
        getContext!H(i).handler;
    }

    final auto getHandler(H)()
    {
        auto ctx = getContext!H();
        if (ctx)
            return ctx.handler;
        return null;
    }

    pragma(inline)
    auto getContext(H)(int i)
    {
        auto ctx = cast(ContextType!H)(_ctxs[i]);
        assert(ctx);
        return ctx;
    }

    auto getContext(H)()
    {
        foreach (i; 0 .. _ctxs.length)
        {
            auto tctx = _ctxs.at(i);
            auto ctx = cast(ContextType!H)(tctx);
            if (ctx)
                return ctx;
        }
        return null;
    }

    void finalize();

    final void detachHandlers()
    {
        foreach (i; 0 .. _ctxs.length)
        {
            auto ctx = _ctxs[i];
            ctx.detachPipeline();
        }
    }

protected:
    PipelineContext[] _ctxs;
    PipelineContext[] _inCtxs;
    PipelineContext[] _outCtxs;

    bool _isFinalize = true;
private:
    PipelineManager _manager = null;
    BaseTransport _transport;
    //	AsynTransportInfo _transportInfo;

    final PipelineBase addHelper(Context)(Context ctx, bool front)
    {
        PipelineContext[] addBefore(PipelineContext[] ctxs, Context ctx){
            auto tctxs = new PipelineContext[ctxs.length + 1];
            tctxs[0] = ctx;
            tctxs[1..$] = ctxs[0..$];
            return tctxs;

        }
        _isFinalize = false;
        front ? _ctxs = addBefore(_ctxs,ctx) : _ctxs ~= ctx;
        if (Context.dir == HandlerDir.BOTH || Context.dir == HandlerDir.IN)
        {
            front ? _inCtxs = addBefore(_inCtxs,ctx) : _inCtxs ~= ctx;
            //front ? _inCtxs.insertBefore(ctx) : _inCtxs.insertBack(ctx);
        }
        if (Context.dir == HandlerDir.BOTH || Context.dir == HandlerDir.OUT)
        {
            front ? _outCtxs = addBefore(_outCtxs,ctx) : _outCtxs ~= ctx;
            //front ? _outCtxs.insertBefore(ctx) : _outCtxs.insertBack(ctx);
        }
        return this;
    }

    final PipelineBase removeHelper(H)(H handler, bool checkEqual)
    {
        bool removed = false;

        for (size_t i = 0; i < _ctxs.length; ++i)
        {
            auto ctx = cast(ContextType!H) _ctxs[i];
            if (ctx && (!checkEqual || ctx.getHandler() == handler))
            {
                removeAt(i);
                removed = true;
                --i;
                break;
            }
        }
        if (!removed)
        {
			throw new HandlerNotInPipelineException("No such handler in pipeline");
        }

        return *this;
    }

    final void removeAt(size_t site)
    {
        import kiss.array;
        _isFinalize = false;
        PipelineContext rctx = _ctxs[site];
        rctx.detachPipeline();
        removeSite(_ctxs,site);
        //_ctxs.removeSite(site);

        import std.algorithm.searching;

        const auto dir = rctx.getDirection();
        if (dir == HandlerDir.BOTH || dir == HandlerDir.IN)
        {
            arrayRemove(_inCtxs,rctx,true);
           // _inCtxs.removeOne(rctx);
        }

        if (dir == HandlerDir.BOTH || dir == HandlerDir.OUT)
        {
            arrayRemove(_inCtxs,rctx,true);
            //_outCtxs.removeOne(rctx);
        }
    }
}

/*
 * R is the inbound type, i.e. inbound calls start with pipeline.read(R)
 * W is the outbound type, i.e. outbound calls start with pipeline.write(W)
 *
 * Use Unit for one of the types if your pipeline is unidirectional.
 * If R is void, read(),  will be disabled.
 * If W is Unit, write() and close() will be disabled.
 */

final class Pipeline(R, W = void) : PipelineBase
{
    alias Ptr = Pipeline!(R, W);

    static Ptr create()
    {
        return new Ptr();
    }

    ~this()
    {
//        if (!_isStatic)  // USE GC, maybe the contex will free before pipeline
//        {
//            detachHandlers();
//        }
    }

    pragma(inline)
    void read(R msg)
    {
        static if (!is(R == void))
        {
            if (_front)
                _front.read(msg);
            else
				throw new NotHasInBoundException("read(): not have inbound handler in Pipeline");
        }
    }

    pragma(inline,true)
    void timeOut()
    {
        static if (!is(R == void))
        {
            if (_front)
                _front.timeOut();
            else
				throw new NotHasInBoundException("timeOut(): not have inbound handler in Pipeline");
        }
    }

    pragma(inline)
    void transportActive()
    {
        static if (!is(R == void))
        {
            if (_front)
            {
                _front.transportActive();
            }
        }
    }

    pragma(inline)
    void transportInactive()
    {
        static if (!is(R == void))
        {
            if (_front)
            {
                _front.transportInactive();
            }
        }
    }

    static if (!is(W == void))
    {
        alias TheCallBack = void delegate(W, size_t);
        pragma(inline)
        void write(W msg, TheCallBack cback = null)
        {

            if (_back)
                _back.write(msg, cback);
            else
				throw new NotHasOutBoundException("close(): no outbound handler in Pipeline");
        }
    }

    pragma(inline)
    void close()
    {
        static if (!is(W == void))
        {
            if (_back)
                _back.close();
            else
				throw new NotHasOutBoundException("close(): no outbound handler in Pipeline");
        }
    }

    override void finalize()
    {
        if (_isFinalize)
            return;
        _front = null;
        static if (!is(R == void))
        {
            if (!_inCtxs.empty())
            {
                _front = cast(InboundLink!R)(_inCtxs[0]);
                for (size_t i = 0; i < _inCtxs.length - 1; i++)
                {
                    _inCtxs[i].setNextIn(_inCtxs[i + 1]);
                }
                _inCtxs[_inCtxs.length - 1].setNextIn(null);
            }
        }

        _back = null;
        static if (!is(W == void))
        {

            if (!_outCtxs.empty())
            {
                _back = cast(OutboundLink!W)(_outCtxs[_outCtxs.length - 1]);
                for (size_t i = _outCtxs.length - 1; i > 0; --i)
                {
                    _outCtxs[i].setNextOut(_outCtxs[i - 1]);
                }
                _outCtxs[0].setNextOut(null);
            }
        }

        for (int i = 0; i < _ctxs.length; ++i)
        {
            _ctxs[i].attachPipeline();
        }

        if (_front is null && _back is null)
			throw new PipelineEmptyException("No Handler in the Pipeline");

        _isFinalize = true;
    }

protected:
    this()
    {
        super();
    }

    this(bool isStatic)
    {
        _isStatic = isStatic;
        super();
    }

private:
    bool _isStatic = false;

    static if (!is(R == void))
    {
        InboundLink!R _front = null;
    }
    else
    {
        Object _front = null;
    }

    static if (!is(W == void))
    {
        OutboundLink!W _back = null;
    }
    else
    {
        Object _back = null;
    }
}

abstract shared class PipelineFactory(PipeLine)
{
    PipeLine newPipeline(TcpStream transport);
}

alias AcceptPipeline = Pipeline!(Socket, uint);
abstract shared class AcceptPipelineFactory
{
    AcceptPipeline newPipeline(TcpListener acceptor);
}
