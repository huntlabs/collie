module collie.bootstrap.serverbootstrap;

import std.container.rbtree;

import collie.socket;
import collie.channel;


final class ServerBootStrap(PipeLine)
{
	this()
	{
		_loop = new EventLoop();
	}

	auto pipeline(AcceptPipelineFactory factory)
	{
		_acceptPipelineFactory = factory;
		return this;
	}

	/*	auto acceptorConfig(const ServerSocketConfig accConfig) {
	 _accConfig = accConfig;
	 return this;
	 } */

	auto childPipeline(PipelineFactory!PipeLine factory)
	{
		_childPipelineFactory = factory;
		return this;
	}

	
	auto group(EventLoopGroup group)
	{
		_group = group;
		return this;
	}

	auto setReusePort(bool ruse)
	{
		_rusePort = ruse;
		return this;
	}

	void bind(Address addr)
	{
		_address = addr;
	}

	void stop()
	{
		if(!_runing) return;
		foreach(ref accept ; _serverlist) {
			accept.stop();
		}
		_mainAccept.stop();
		join();
		_loop.stop();
		_runing = false;
	}

	void join()
	{
		if(!_runing) return;
		if(_group)
			_group.wait();
	}

	
	void waitForStop()
	{
		if(_runing) return;
		if(_address is null || _childPipelineFactory is null) return;
		_mainAccept = creatorAcceptor(_loop);
		_mainAccept.initialize();
		if(_group) {
			for (uint i = 0; i < _group.length; ++i){
				auto acceptor =  creatorAcceptor(_group[i]);
				acceptor.initialize();
				_serverlist ~= acceptor;
			}
			_group.start();
		}
		_loop.run();
	}

protected:
	auto creatorAcceptor(EventLoop loop)
	{
		auto accept = new Accept(loop,_address.addressFamily == AddressFamily.INET6);
		accept.reusePort = _rusePort;
		accept.bind(_address);
		accept.listen(128);
		AcceptPipeline pipe;
		if(_acceptPipelineFactory)
			pipe = _acceptPipelineFactory.newPipeline(accept);
		else
			pipe = AcceptPipeline.create();
		return new ServerAceptor!(PipeLine)(accept,pipe,_childPipelineFactory);
	}

private:
	AcceptPipelineFactory  _acceptPipelineFactory;
	PipelineFactory!PipeLine _childPipelineFactory;

	ServerAceptor!(PipeLine) _mainAccept;
	EventLoop _loop;

	ServerAceptor!(PipeLine)[] _serverlist;
	EventLoopGroup _group;

	bool _runing = false;
	bool _rusePort = true;
	Address _address;
}

private :

import std.functional;

bool serverAceptorCmp(T)(inout T a, T b)
{
	return a.opCmp(b);
}

final class ServerAceptor(PipeLine) : InboundHandler!(Socket)
{
	this(Accept accept,AcceptPipeline pipe, PipelineFactory!PipeLine clientPipeFactory)
	{
		_accept = accept;
		_pipeFactory = clientPipeFactory;
		pipe.addBack(this);
		pipe.finalize();
		_pipe = pipe;
		_pipe.transport(_accept);
		_accept.setCallBack(&acceptCallBack);
		//_list = new int[ServerConnection!PipeLine];//RedBlackTree!(ServerConnection!PipeLine)();
	}
	
	void initialize()
	{
		_pipe.transportActive();
	}

	void stop()
	{
		_pipe.transportInactive();
	}
	
	override void read(Context ctx, Socket msg)
	{
		auto asyntcp = new TCPSocket(_accept.eventLoop,msg);
		auto pipe = _pipeFactory.newPipeline(asyntcp);
		if(!pipe) return;
		pipe.finalize();
		auto con = new ServerConnection!PipeLine(pipe);
		con.serverAceptor = this;
		//_list.stableInsert(con);
		_list[con] = 0;
		con.initialize();
	}
	
	override void transportActive(Context ctx)
	{
		_accept.start();
	}

	override void transportInactive(Context ctx) 
	{
		_accept.close();
		foreach (con , value; _list){
			con.close();
		}
		_list.clear();
		_accept.eventLoop.stop();
	}
	
	void remove(ServerConnection!PipeLine conn)
	{
		_list.remove(conn);
	}
	
	void acceptCallBack(Socket soct)
	{
		_pipe.read(soct);
	}

	@property acceptor(){return _accept;}
	
private:
	int[ServerConnection!PipeLine] _list;
	//RedBlackTree!(ServerConnection!PipeLine) _list;
	Accept _accept;
	AcceptPipeline _pipe;
	PipelineFactory!PipeLine _pipeFactory;
}

final class ServerConnection(PipeLine) : PipelineManager
{
	this(PipeLine pipe)
	{
		_pipe = pipe;
		_pipe.pipelineManager = this;
	}
	
	void initialize()
	{
		_pipe.transportActive();
	}
	
	void close()
	{
		_pipe.transportInactive();
	}

	@property serverAceptor()
	{
		return _manger;
	}
	
	@property serverAceptor(ServerAceptor!PipeLine manger)
	{
		_manger = manger;
	}
	
	override void deletePipeline(PipelineBase pipeline)
	{
		_manger.remove(this);
		pipeline.pipelineManager = null;
		_pipe = null;
		_manger = null;
	}
	
	override void refreshTimeout()
	{}

private:
	ServerAceptor!PipeLine _manger;
	PipeLine _pipe;
}
