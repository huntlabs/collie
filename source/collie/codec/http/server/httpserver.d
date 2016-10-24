module collie.codec.http.server.httpserver;

import collie.codec.http.httpsession;
import collie.codec.http.httptansaction;
import collie.codec.http.server.httpserveroptions;
import collie.codec.http.httpmessage;
import collie.codec.http.server.requesthandler;
import collie.codec.http.codec.httpcodec;
import collie.codec.http.httptansaction;
import collie.bootstrap.server;
import collie.utils.vector;
import collie.channel;
import collie.socket.tcpsocket;
import collie.socket.acceptor;
import collie.socket.eventloop;
import collie.socket.eventloopgroup;


import std.socket;
import std.experimental.allocator.gc_allocator;


alias HTTPPipeline = Pipeline!(ubyte[],ubyte[]);

final class HTTPServer : HTTPSessionController
{
	alias Server = ServerBootstrap!HTTPPipeline;
	alias SVector = Vector!(Server,GCAllocator);
	alias IPVector = Vector!(HTTPServerOptions.IPConfig,GCAllocator);

	this(HTTPServerOptions options)
	{
		_options = options;
		_mainLoop = new EventLoop();
		size_t thread = _options.threads - 1;
		if(thread > 0) {
			_group = new EventLoopGroup(cast(uint)thread);
		}
	}

	void bind(ref IPVector addrs)
	{
		if(_isStart) return;
		_ipconfigs = addrs;
		for(size_t i = 0; i < _servers.length; ++i)
		{
			_servers[i].stopListening();
		}
		_servers.clear();
		for(size_t i = 0; i < _ipconfigs.length; ++i)
		{
			newServer(_ipconfigs[i]);
		}
	}

	void addBind(ref HTTPServerOptions.IPConfig addr)
	{
		if(_isStart) return;
		newServer(addr);
		_ipconfigs.insertBack(addr);
	}

	void start()
	{
		if(_isStart) return;
		for(size_t i = 0; i < _servers.length; ++i)
		{
			_servers[i].startListening();
		}
		if(_group)
			_group.start();
		_mainLoop.run();
	}

	void stop()
	{
		if(!_isStart) return;
		if(_group)
			_group.stop();
		_mainLoop.stop();
	}

	ref const(IPVector) addresses() const{ return _ipconfigs;}
	EventLoop eventLoop(){return _mainLoop;}
	EventLoopGroup group(){return _group;}
	ref const(SVector) servers(){return _servers;}
protected:
	override HTTPTransactionHandler getRequestHandler(HTTPTransaction txn, HTTPMessage msg)
	{/*  will run  in Multi-thread */
		RequestHandler req = null;
		for(size_t i = 0; i < _options.handlerFactories.length; ++i)
		{
			req = _options.handlerFactories[i](req,msg);
		}
		import collie.codec.http.server.requesthandleradaptor;
		RequestHandlerAdaptor ada = new RequestHandlerAdaptor(req);
		ada.setTransaction(txn);
		return ada;
	}

	override void attachSession(HTTPSession session){/*  will run  in Multi-thread */}

	override void detachSession(HTTPSession session){/*  will run  in Multi-thread */}

	override void onSessionCodecChange(HTTPSession session){/*  will run  in Multi-thread */}

	uint maxHeaderSize() const shared {return cast(uint)_options.maxHeaderSize;}

	static void setAcceptorConfig(ref shared(HTTPServerOptions.IPConfig) config,Acceptor acceptor)
	{
		version(linux) {
			if(config.enableTCPFastOpen){
				acceptor.setOption(SocketOptionLevel.TCP,cast(SocketOption)23,config.fastOpenQueueSize);
			}
		}
	}

	void newServer(ref HTTPServerOptions.IPConfig ipconfig )
	{
		Server ser = new Server(_mainLoop);
		if(_group)
			ser.setReusePort(true);
		ser.group(_group).childPipeline(new shared ServerHandlerFactory(this));
		ser.pipeline(new shared ServerAccpeTFactory(ipconfig));
		ser.heartbeatTimeOut(cast(uint)_options.timeOut);
		ser.bind(ipconfig.address);
	}
private:
	SVector _servers;
	EventLoop _mainLoop;
	EventLoopGroup _group = null;


	HTTPServerOptions _options;
	IPVector _ipconfigs;

	bool _isStart = false;
}


private:

import collie.codec.http.httpdownstreamsession;
import collie.codec.http.codec.http1xcodec;

class ServerHandlerFactory : PipelineFactory!HTTPPipeline
{
	this(HTTPServer server)
	{
		_server = cast(typeof(_server))server;
	}
	override HTTPPipeline newPipeline(TCPSocket transport) {
		auto pipe = HTTPPipeline.create();
		pipe.addBack(new TCPSocketHandler(transport));
		pipe.addBack(new HTTPDownstreamSession(cast(HTTPServer)_server,
				new HTTP1XCodec(TransportDirection.DOWNSTREAM,_server.maxHeaderSize)));
		pipe.finalize();
		return pipe;
	}

private:
	HTTPServer _server;
}

class ServerAccpeTFactory : AcceptPipelineFactory
{
	this(HTTPServerOptions.IPConfig config)
	{
		_conf = cast(typeof(_conf))config;
	}

	override AcceptPipeline newPipeline(Acceptor acceptor) {
		AcceptPipeline pipe = AcceptPipeline.create();
		HTTPServer.setAcceptorConfig(_conf,acceptor);
		return pipe;
	}

private:
	HTTPServerOptions.IPConfig _conf;
}