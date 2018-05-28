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
module collie.codec.http.server.httpserver;
import kiss.logger;
import collie.codec.http.session.httpsession;
import collie.codec.http.httptansaction;
import collie.codec.http.server.httpserveroptions;
import collie.codec.http.httpmessage;
import collie.codec.http.server.requesthandler;
import collie.codec.http.codec.httpcodec;
import collie.codec.http.httptansaction;
import collie.bootstrap.server;
import kiss.container.Vector;
import collie.channel;
import kiss.net.TcpStream;
import kiss.event;
import kiss.net.TcpListener;
import kiss.event.socket;

import collie.net.server.tcpserver;
import collie.net.server.connection;
import collie.bootstrap.exception;
import collie.bootstrap.exception;
import collie.bootstrap.serversslconfig;

import std.socket;
import std.parallelism;

alias HTTPPipeline = Pipeline!(const(ubyte[]), StreamWriteBuffer);
alias HTTPServer = HTTPServerImpl!true;
alias HttpServer = HTTPServerImpl!false;

final class HTTPServerImpl(bool UsePipeline) : HTTPSessionController
{
	static if(UsePipeline){
		alias Server = ServerBootstrap!HTTPPipeline;
	} else {
		alias Server = TCPServer;
	}
	alias SVector = Vector!(Server);
	alias IPVector = Vector!(HTTPServerOptions.IPConfig);

	this(HTTPServerOptions options)
	{
		version(USE_SSL){
			if(options.ssLConfig){
				_ssl_Ctx = options.ssLConfig.generateSSLCtx();
				if(_ssl_Ctx is null)
					throw new SSLException("can not generate SSL_Ctx!");
			}
		}
		_options = options;
		_mainLoop = new EventLoop();
		size_t thread = _options.threads - 1;
		if(thread > 0) {
			if(thread>totalCPUs) thread = totalCPUs-1;
			_group = new EventLoopGroup(cast(uint)thread);
		}

	}

	void bind(ref IPVector addrs)
	{
		if(_isStart) return;
		_ipconfigs = addrs;
		for(size_t i = 0; i < _servers.length; ++i)
		{
			logDebug("start listen!!!");
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
		// logDebug("",_isStart);
		if(_isStart) return;
		newServer(addr);
		_ipconfigs.insertBack(addr);
	}

	void start()
	{
		// logDebug("start ",_isStart);
		if(_isStart) return;
		_isStart = true;
		for(size_t i = 0; i < _servers.length; ++i)
		{
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
		RequestHandlerAdaptor ada = new RequestHandlerAdaptor(req);
		ada.setTransaction(txn);
		return ada;
	}

	override void attachSession(HTTPSession session){/*  will run  in Multi-thread */}

	override void detachSession(HTTPSession session){/*  will run  in Multi-thread */}

	override void onSessionCodecChange(HTTPSession session){/*  will run  in Multi-thread */}

	uint maxHeaderSize() const shared {return cast(uint)_options.maxHeaderSize;}

	static if(UsePipeline){
		static void setAcceptorConfig(ref shared(HTTPServerOptions.IPConfig) config,TcpListener acceptor)
		{
			version(linux) {
				if(config.enableTCPFastOpen){
					acceptor.setOption(SocketOptionLevel.TCP,cast(SocketOption)23,config.fastOpenQueueSize);
				}
			}
		}
	}

	void newServer(HTTPServerOptions.IPConfig ipconfig )
	{
		static if(UsePipeline){
			Server ser = new Server(_mainLoop);
			if(_group)
				ser.setReusePort(true);
			ser.group(_group).childPipeline(new shared ServerHandlerFactory(this));
			version(USE_SSL){
				if(_options.ssLConfig)
					ser.setSSLConfig(_options.ssLConfig);
			}
			ser.pipeline(new shared ServerAccpeTFactory(ipconfig));
			ser.heartbeatTimeOut(cast(uint)_options.timeOut);
			ser.bind(ipconfig.address);
			logDebug("binding on: ", ipconfig.address.toString());
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
			Server ser = new Server(loop);
			ser.setNewConntionCallBack(&newConnect);
			logDebug("binding on: ", address.toString());

			ser.bind(address,(TcpListener accpet) @trusted {
					if(ruseport)
						accpet.reusePort(true);
					else {
						version(windows){
							import core.sys.windows.winsock2;
							accpet.setOption(SocketOptionLevel.SOCKET, cast(SocketOption)SO_EXCLUSIVEADDRUSE,true);
						} else {
							accpet.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
						}
					}
					version(linux) {
						if(enableTCPFastOpen){
							accpet.setOption(SocketOptionLevel.TCP,cast(SocketOption)23,fastOpenQueueSize);
						}
					}
				});
			return ser;
		}
	}


	ServerConnection newConnect(TcpListener sender, TcpStream stream) 
	{
		return new HttpHandlerConnection(stream,this,
			new HTTP1XCodec(TransportDirection.DOWNSTREAM,cast(uint)_options.maxHeaderSize));
	}
private:
	SVector _servers;
	EventLoop _mainLoop;
	EventLoopGroup _group = null;


	HTTPServerOptions _options;
	IPVector _ipconfigs;
	SSL_CTX * _ssl_Ctx = null;

	bool _isStart = false;
}


private:

import collie.codec.http.codec.http1xcodec;
import collie.codec.http.session.httpdownstreamsession;
import collie.codec.http.session.sessiondown;

class HttpHandlerConnection : HTTPConnection
{
	this(TcpStream sock,HTTPSessionController controller,HTTPCodec codec)
	{
		super(sock);
		httpSession = new HTTPDownstreamSession(controller,codec,this);
	}
}

class HttpHandlerPipeline : PipelineSessionDown
{
	this(HTTPSessionController controller,HTTPCodec codec)
	{
		httpSession(new HTTPDownstreamSession(controller,codec,this));
	}
}

class ServerHandlerFactory : PipelineFactory!HTTPPipeline
{
	this(HTTPServer server)
	{
		_server = cast(typeof(_server))server;
	}
	override HTTPPipeline newPipeline(TcpStream transport) {
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

	override AcceptPipeline newPipeline(TcpListener acceptor) {
		logDebug("--new accpetPipeLine");
		AcceptPipeline pipe = AcceptPipeline.create();
		HTTPServer.setAcceptorConfig(_conf,acceptor);
		return pipe;
	}

private:
	HTTPServerOptions.IPConfig _conf;
}