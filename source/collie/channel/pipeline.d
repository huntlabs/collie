module collie.channel.pipeline;

import std.typecons;
import std.variant;
import std.container.array;
import std.functional;

import collie.channel.handler;
import collie.channel.handlercontext;
import collie.socket;

interface PipelineManager {
	void deletePipeline(PipelineBase pipeline);
	void refreshTimeout();
};

abstract class PipelineBase
{
	this()
	{
	}

	@property final void pipelineManager(PipelineManager manager)
	{
		_manager = manager;
	}

	@property final PipelineManager pipelineManager()
	{
		return _manager;
	}

	final void deletePipeline()
	{
		if(_manager) {
			_manager.deletePipeline(this);
		}
	}

	@property final void transport(AsyncTransport transport)
	{
		_transport = transport;
	}

	@property final transport(){return _transport;}

	
	//	@property transportInfo(AsyncTransport tcpInfo){_transportInfo = tcpInfo};
	//	@property transportInfo(){return _transportInfo;};

	
	final PipelineBase addBack(H)(H handler)
	{
		return addHelper(new ContextType!(H)(this,handler),false);
	}

	final PipelineBase addFront(H)(H handler)
	{
		return addHelper(new ContextType!(H)(this,handler),true);
	}

	final PipelineBase remove(H)(H handler)
	{
		return removeHelper!H(handler,true);
	}

	final PipelineBase remove(H)()
	{
		return removeHelper!H(null, false);
	}

	final PipelineBase removeFront()
	{
		if (_ctxs.empty()) {
			throw new Exception("No handlers in pipeline");
		}
		removeAt(0);
		return this;
	}

	final PipelineBase removeBack()
	{
		if (_ctxs.empty()) {
			throw new Exception("No handlers in pipeline");
		}
		removeAt(_ctxs.length - 1);
		return this;
	}

	final auto getHandler(H)(int i)
	{
		getContext!H(i).handler;
	}

	final auto getHandler(H)()
	{
		auto ctx = getContext!H();
		if(ctx) return ctx.handler;
		return null;
	}

	auto getContext(H)(int i)
	{
		auto ctx = cast(ContextType!H)(_ctxs[i]);
		assert(ctx);
		return ctx;
	}

	auto getContext(H)()
	{
		foreach(tctx;_ctxs){
			auto ctx = cast(ContextType!H)(tctx);
			if(ctx) return ctx;
		}
		return null;
	}

	
	// If one of the handlers owns the pipeline itself, use setOwner to ensure
	// that the pipeline doesn't try to detach the handler during destruction,
	// lest destruction ordering issues occur.
	// See thrift/lib/cpp2/async/Cpp2Channel.cpp for an example
	final bool setOwner(H)(H handler)
	{
		foreach (ctx ; _ctxs) {
			auto ctxImpl = cast(ContextType!H)(ctx);
			if (ctxImpl && ctxImpl.getHandler() == handler) {
				owner_ = ctx;
				return true;
			}
		}
		return false;
	}

	void finalize();

	final void detachHandlers()
	{
		foreach (ctx ; _ctxs) {
			if (ctx != _owner) {
				ctx.detachPipeline();
			}
		}
	}

protected :
	Array!PipelineContext _ctxs;
	Array!PipelineContext _inCtxs;
	Array!PipelineContext _outCtxs;

	bool _isFinalize = true;
private :
	PipelineManager _manager = null;
	AsyncTransport _transport;
	//	AsynTransportInfo _transportInfo;
	PipelineContext _owner;
	
	final PipelineBase addHelper(Context)(Context ctx, bool front)
	{
		_isFinalize = false;
		front ? _ctxs.insertBefore(_ctxs[0..0],ctx) : _ctxs.insertBack(ctx);
		if (Context.dir == HandlerDir.BOTH || Context.dir == HandlerDir.IN) {
			front ? _inCtxs.insertBefore(_inCtxs[0..0],ctx) : _inCtxs.insertBack(ctx);
		}
		if (Context.dir == HandlerDir.BOTH || Context.dir == HandlerDir.OUT) {
			front ? _outCtxs.insertBefore(_outCtxs[0..0],ctx) : _outCtxs.insertBack(ctx);
		}
		return this;
	}

	final PipelineBase removeHelper(H)(H handler, bool checkEqual) 
	{
		bool removed = false;

		for (int i = 0; i < _ctxs.length; ++i) {
			auto ctx = cast(ContextType!H)_ctxs[i];
			if(ctx && (!checkEqual || ctx.getHandler() == handler)) {
				removeAt(site);
				removed = true;
				--i;
				break;
			}
		}
		if (!removed) {
			throw new Exception("No such handler in pipeline");
		}

		return *this;
	}

	final void removeAt(size_t site)
	{
		_isFinalize = false;
		PipelineContext rctx = _ctxs[site];
		rctx.detachPipeline();
		_ctxs.linearRemove(_ctxs[site..(site + 1)]);
		
		import std.algorithm.searching;
		
		const auto dir = rctx.getDirection();
		if (dir == HandlerDir.BOTH || dir == HandlerDir.IN) {
			auto rm = find(_inCtxs[0..$],rctx);
			_inCtxs.linearRemove(rm[0..1]);
		}
		
		if (dir == HandlerDir.BOTH || dir == HandlerDir.OUT) {
			auto rm = find(_outCtxs[0..$],rctx);
			_outCtxs.linearRemove(rm[0..1]);
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
	alias Pipeline!(R,W) Ptr;

	
	static Ptr create()
	{
		return new Ptr();
	}

	static if(!is(R == void)) {
		void read(R msg)
		{
			if(_front)
				_front.read(forward!(msg));
			else
				throw new Exception("read(): no outbound handler in Pipeline");
		}
	}

	void transportActive()
	{
		if (_front) {
			_front.transportActive();
		}
	}

	void transportInactive()
	{
		if (_front) {
			_front.transportActive();
		}
	}

	static if(!is(W == void)) {
		alias TheCallBack = void delegate(W,uint);
		void write(W msg,TheCallBack cback = null)
		{
			if(_back)
				_back.write(forward!(msg,cback));
			else
				throw new Exception("close(): no outbound handler in Pipeline");
		}

		void close()
		{
			if(_back)
				_back.close();
			else
				throw new Exception("close(): no outbound handler in Pipeline");
		}
	}

	override void finalize()
	{
		if(_isFinalize) return;
		_front = null;
		static if(!is(R == void)) {
			if (!_inCtxs.empty()) {
				_front = cast(InboundLink!R)(_inCtxs[0]);
				for (size_t i = 0; i < _inCtxs.length - 1; i++) {
					_inCtxs[i].setNextIn(_inCtxs[i+1]);
				}
				_inCtxs[_inCtxs.length - 1].setNextIn(null);
			}
		}

		_back = null;
		static if(!is(W == void)) {

			if (!_outCtxs.empty()) {
				_back = cast(OutboundLink!W)(_outCtxs[_outCtxs.length - 1]);
				for (size_t i = _outCtxs.length - 1; i > 0; --i) {
					_outCtxs[i].setNextOut(_outCtxs[i-1]);
				}
				_outCtxs[0].setNextOut(null);
			}
		}
		
		for (int i = 0 ; i <  _ctxs.length(); ++i) {
			_ctxs[i].attachPipeline();
		}
		
		if(_front is null && _back is null) throw new Exception("No Handler in the Pipeline");
		
		_isFinalize = true;
	}

protected :
	this(){};
	this(bool isStatic){_isStatic = isStatic;};
private :
	bool _isStatic = false;

	static if(!is(R == void)) {
		InboundLink!R  _front = null;
	} else {
		Object _front = null;
	}
	static if(!is(W == void)) {
		OutboundLink!W _back = null;
	}else {
		Object _back = null;
	}
}

abstract class PipelineFactory(PipeLine)
{
	PipeLine newPipeline(TCPSocket transport);
}


alias Pipeline!(Socket,void) AcceptPipeline;
abstract class AcceptPipelineFactory
{
	AcceptPipeline newPipeline(Accept acceptor);
}

