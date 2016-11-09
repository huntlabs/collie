module collie.codec.http.server.httpserver;

import collie.codec.http.session.httpsession;
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
import collie.socket.server.tcpserver;
import collie.socket.server.connection;

import std.socket;
import std.experimental.allocator.gc_allocator;
import std.experimental.logger;


alias HTTPPipeline = Pipeline!(ubyte[],ubyte[]);
alias HTTPServer = HTTPServerImpl!true;
alias HttpServer = HTTPServerImpl!false;

final class HTTPServerImpl(bool UsePipeline) : HTTPSessionController
{
	static if(UsePipeline){
		alias Server = ServerBootstrap!HTTPPipeline;
	} else {
		alias Server = TCPServer;
	}
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
			trace("start listen!!!");
			static if(UsePipeline)
				_servers[i].stopListening();
			else
				_servers[i].close();
		}
		_servers.clear();
		for(size_t i = 0; i < _ipconfigs.length; ++i)
		{
			newServer(_ipconfigs[i]);
		}
	}

	void addBind(ref HTTPServerOptions.IPConfig addr)
	{
		trace("",_isStart);
		if(_isStart) return;
		newServer(addr);
		_ipconfigs.insertBack(addr);
	}

	void start()
	{
		trace("start ",_isStart);
		if(_isStart) return;
		_isStart = true;
		for(size_t i = 0; i < _servers.length; ++i)
		{
			trace("start listen ---");
			static if(UsePipeline)
				_servers[i].startListening();
			else {
				Server ser = _servers[i];
				ser.startTimeout(cast(uint)_options.timeOut);
				ser.listen(1024);
			}
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
		if(req is null)
			return null;
		import collie.codec.http.server.requesthandleradaptor;
		RequestHandlerAdaptor ada = new RequestHandlerAdaptor(req);
		ada.setTransaction(txn);
		return ada;
	}

	override void attachSession(HTTPSession session){/*  will run  in Multi-thread */}

	override void detachSession(HTTPSession session){/*  will run  in Multi-thread */}

	override void onSessionCodecChange(HTTPSession session){/*  will run  in Multi-thread */}

	uint maxHeaderSize() const shared {return cast(uint)_options.maxHeaderSize;}

	static if(UsePipeline){
		static void setAcceptorConfig(ref shared(HTTPServerOptions.IPConfig) config,Acceptor acceptor)
		{
			version(linux) {
				if(config.enableTCPFastOpen){
					acceptor.setOption(SocketOptionLevel.TCP,cast(SocketOption)23,config.fastOpenQueueSize);
				}
			}
		}
	}

	void newServer(ref HTTPServerOptions.IPConfig ipconfig )
	{
		static if(UsePipeline){
			Server ser = new Server(_mainLoop);
			if(_group)
				ser.setReusePort(true);
			ser.group(_group).childPipeline(new shared ServerHandlerFactory(this));
			ser.pipeline(new shared ServerAccpeTFactory(ipconfig));
			ser.heartbeatTimeOut(cast(uint)_options.timeOut);
			ser.bind(ipconfig.address);
			_servers.insertBack(ser);
		} else {
			bool ruseport = _group !is null;
			_servers.insertBack(newTCPServer(_mainLoop,ipconfig.address,ruseport,ipconfig.enableTCPFastOpen,ipconfig.fastOpenQueueSize));
			if(ruseport){
				foreach(EventLoop loop; _group){
					_servers.insertBack(newTCPServer(loop,ipconfig.address,ruseport,ipconfig.enableTCPFastOpen,ipconfig.fastOpenQueueSize));
				}
			}

		}
	}
	static if(!UsePipeline){
		Server newTCPServer(EventLoop loop,Address address,bool ruseport, bool enableTCPFastOpen, uint fastOpenQueueSize )
		{
			Server ser = new Server(_mainLoop);
			ser.setNewConntionCallBack(&newConnect);
			ser.bind(address,(Acceptor accpet){
					if(ruseport)
						accpet.reusePort(true);
					version(linux) {
						if(enableTCPFastOpen){
							accpet.setOption(SocketOptionLevel.TCP,cast(SocketOption)23,fastOpenQueueSize);
						}
					}
				});
			return ser;
		}
	}


	ServerConnection newConnect(EventLoop loop,Socket sock)
	{
		return new HttpHandlerConnection(new TCPSocket(loop,sock),this,
			new HTTP1XCodec(TransportDirection.DOWNSTREAM,cast(uint)_options.maxHeaderSize));
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

import collie.codec.http.codec.http1xcodec;
import collie.codec.http.session.httpdownstreamsession;
import collie.codec.http.session.sessiondown;

class HttpHandlerConnection : HTTPConnection
{
	this(TCPSocket sock,HTTPSessionController controller,HTTPCodec codec)
	{
		super(sock);
		httpSession = new HTTPDownstreamSession(controller,codec,this);
	}
}

class HttpHandlerPipeline : PipelineSessionDown
{
	this(HTTPSessionController controller,HTTPCodec codec)
	{
		httpSession = new HTTPDownstreamSession(controller,codec,this);
	}
}

class ServerHandlerFactory : PipelineFactory!HTTPPipeline
{
	this(HTTPServer server)
	{
		_server = cast(typeof(_server))server;
	}
	override HTTPPipeline newPipeline(TCPSocket transport) {
		auto pipe = HTTPPipeline.create();
		pipe.addBack(new TCPSocketHandler(transport));
		pipe.addBack(new HttpHandlerPipeline(cast(HTTPServer)_server,
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
		trace("--new accpetPipeLine");
		AcceptPipeline pipe = AcceptPipeline.create();
		HTTPServer.setAcceptorConfig(_conf,acceptor);
		return pipe;
	}

private:
	HTTPServerOptions.IPConfig _conf;
}