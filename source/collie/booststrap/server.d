module collie.booststrap.server;

import collie.channel;
import core.thread;
import std.parallelism;
import std.stdio;
import collie.handler.basehandler;
import collie.channel.utils.queue;
import core.sync.mutex;

version(SSL) {
	alias  SSLServerBoostStarp = ServerBoostStarpImpl!(true);
}
alias  ServerBoostStarp = ServerBoostStarpImpl!(false);

alias pipelineFactory = void delegate (PiPeline pip);

final class ServerBoostStarpImpl(bool ssl)
{
	this() {
		this(new EventLoop());
	}

	this(EventLoop loop) {
		_loop = loop;
		static if(ssl) {
			_listen = new SSLlistener(_loop);
		} else {
			_listen = new TCPListener(_loop);
		}
		_listen.setConnectHandler(&onConnection);
		_listen.setAcceptErrorHandler(&acceptErro);
		_threadsize = totalCPUs;
		_mutex = new Mutex();
		_loopList = SqQueue!EventLoop(16);
	}

	
	auto setOption(T)(TCPOption option, in T value)
	{
		_listen.setOption(option,value);
		return this;
	}

	
	auto bind(Address addr)
	{
		_addr = addr;
		return this;
	}

	
	auto setPipelineFactory(pipelineFactory pipFac)
	{
		_pipelineFactory = pipFac;
		return this;
	}

	
	auto setThreadSize(uint size)
	{
		_threadsize = size;
		if (_loopList.maxLength <  _threadsize){
			_loopList = SqQueue!EventLoop(_threadsize + 4);
		}
		return this;
	}

	void run()
	{
		trace("startt run");
		Thread.getThis.name = "ServerBoostStarp_main";
		if (!_addr.isVaild) {
			writeln("address erro !");
			return ;
		}
		if (!_listen.listen(_addr)){
			_listen.kill();
			error("listen erro !");
			return ;
		}
		uint size = _threadsize -1;
		if(size > 0) {
			_thread.length = size;
			foreach (i ; 0..size) {
				auto th = new Thread(&listRun);
				th.name = "ServerBoostStarp_Thread_"~to!string(i);
				trace("start thread : ",th.name);
				_thread[i]= th;
				th.start();
			}
		} else {
			_thread = null;
		}
		_loop.run();
		info("loop stop! at ",Thread.getThis.name);
		_listen.kill();
		info("exit listen at ",Thread.getThis.name);
		foreach(th;_thread){
			th.join(false);
		}
	}

	
	@property EventLoop eventLoop(){return _loop;}

	void stop(){
		_loop.stop();
		while(!_loopList.empty){
			EventLoop loop;
			synchronized(_mutex) {
				loop = _loopList.deQueue(null);
			}
			if(loop)
				loop.stop();
		}
	}

	static if (ssl){
		
		bool setCertificateFile(string file){
			_cfile = file;
			return _listen.setCertificateFile(_cfile);
		}

		
		bool setPrivateKeyFile(string file) {
			_pkey = file;
			return _listen.setPrivateKeyFile(_pkey);
		}
	}

protected:
	void listRun()
	{
		auto loop = new EventLoop();
		synchronized(_mutex){
			_loopList.enQueue(loop);
		}
		static if(ssl) {
			scope auto listen = new SSLlistener(loop);
			listen.setConnectHandler(&onConnection);
		} else {
			scope auto listen = new TCPListener(loop);
			listen.setConnectHandler(&onConnection);
		}
		listen.setAcceptErrorHandler(&acceptErro);

		static if(ssl) {
			if(!listen.setCertificateFile(_cfile)){
				error("setCertificateFile err0: at ",Thread.getThis.name);
				return;
			}
			if(!listen.setPrivateKeyFile(_cfile)){
				error("setPrivateKeyFile err0: at ",Thread.getThis.name);
				return;
			}

		}
		if (!listen.listen(_addr)) { 
			error("bind erro at Thread:", Thread.getThis.name);
			return;
		}
		loop.run();
		info("loop stop! at ",Thread.getThis.name);
		listen.kill();
		info("exit listen at ",Thread.getThis.name);
	}

	bool acceptErro(int eron){
		trace("stop server! acceptErro : ",eron);
		stop();
		return false;
	}
	static if(ssl){
		void onConnection (SSLSocket sock)
		{
			auto line = new PiPeline(sock);
			_pipelineFactory(line);
			if(line.isVaild)
				sock.start(); 
		}
	} else {
		void onConnection (TCPSocket sock)
		{
			auto line = new PiPeline(sock);
			_pipelineFactory(line);
			if(line.isVaild)
				sock.start(); 
		}
	}
private:
	EventLoop 	_loop;

	static if(ssl) {
		SSLlistener _listen;
		string _pkey;
		string _cfile;
	} else {
		TCPListener 	_listen;
	}
	Address 		_addr;
	uint 		_threadsize = 2;
	pipelineFactory _pipelineFactory;
	Thread[] 		_thread;
	Mutex   _mutex;
	SqQueue!EventLoop _loopList;
	InHander _handle;
};
