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
module collie.bootstrap.clientmanger;

import collie.net;
import collie.channel;
import kiss.timingwheel;
import collie.utils.memory;
import kiss.functional;
import collie.exception;
import collie.utils.exception;
import collie.net.client.linkinfo;
import std.exception;
import std.experimental.logger;
public import kiss.net.TcpStreamClient;
import kiss.event.task;

final class ClientManger(PipeLine)
{
	alias ClientConnection = ClientLink!PipeLine;
	alias PipeLineFactory = PipelineFactory!PipeLine;
	alias ClientCreatorCallBack = void delegate(TcpStreamClient);
	alias ConnCallBack = void delegate(PipeLine);
	alias LinkManger = TLinkManger!ConnCallBack;
	alias LinkInfo = LinkManger.LinkInfo;

	this(EventLoop loop)
	{
		_loop = loop;
		_list = new ClientConnection();
	}
	
	~this()
	{
		if (_timer)
			_timer.destroy;
	}

	void setClientCreatorCallBack(ClientCreatorCallBack cback)
	{
		_oncreator = cback;
	}

	void pipelineFactory(shared PipeLineFactory fac)
	{
		_factory = fac;
	}

	void connect(Address to, ConnCallBack cback = null)
	{
		LinkInfo * tinfo = new LinkInfo();
		tinfo.addr = to;
		tinfo.tryCount = 0;
		tinfo.cback = cback;
		_loop.postTask(newTask((){
				_waitConnect.addInfo(tinfo);
				connect(tinfo);
			}));
	}

	void close()
	{
		auto con = _list.next;
		_list.next = null;
		while(con) {
			auto tcon = con;
			con = con.next;
			tcon.close();
		}
	}

	@property tryCount(){return _tryCount;}
	@property tryCount(uint count){_tryCount = count;}

	alias heartbeatTimeOut = startTimeOut;
	// 定时器不精确，需要小心误差
	bool startTimeOut(uint s)
	{
		return getTimeWheelConfig(s);
	}

	@property EventLoop eventLoop()
	{
		return _loop;
	}

protected:
	void connect(LinkInfo * info)
	{
		info.client = new TcpStreamClient(_loop);
		if(_oncreator)
			_oncreator(info.client);
		info.client.setCloseHandle(&tmpCloseCallBack);
		info.client.setConnectHandle(bind(&connectCallBack,info));
		info.client.setReadHandle(&tmpReadCallBack);
		info.client.connect(info.addr);
	}

	void connectCallBack(LinkInfo * tinfo,bool isconnect) nothrow @trusted
	{
		catchAndLogException((){
		import std.exception;
		if(tinfo is null)return;
		if(isconnect){
			scope(exit){
				_waitConnect.rmInfo(tinfo);
			}
			PipeLine pipe = null;
			collectException(_factory.newPipeline(tinfo.client),pipe);
			if(tinfo.cback)
				tinfo.cback(pipe);
			if(pipe is null)return;
			ClientConnection con = new ClientConnection(this,pipe);
			_wheel.addNewTimer(con);

			con.next = _list.next;
			if(con.next)
				con.next.prev = con;
			con.prev = _list;
			_list.next = con;

			con.initialize();

		} else {// 重试一次，失败就释放资源
			tinfo.client = null;
			if(tinfo.tryCount < _tryCount) {
				tinfo.tryCount ++;
				connect(tinfo);
			}else{
				auto cback = tinfo.cback;
				_waitConnect.rmInfo(tinfo);
				gcFree(tinfo);
				if(cback)
					cback(null);
			}
		}
		}());
	}

	void tmpCloseCallBack() nothrow{}

	void tmpReadCallBack(in ubyte[] buffer) nothrow{}

	void remove(ClientConnection con)
	{
		con.prev.next = con.next;
		if(con.next)
			con.next.prev = con.prev;
		gcFree(con);
	}

	bool getTimeWheelConfig(uint _timeOut)
	{
		uint whileSize;uint time; 
		if (_timeOut == 0)
			return false;
		if (_timeOut <= 40)
		{
			whileSize = 50;
			time = _timeOut * 1000 / 50;
		}
		else if (_timeOut <= 120)
		{
			whileSize = 60;
			time = _timeOut * 1000 / 60;
		}
		else if (_timeOut <= 600)
		{
			whileSize = 100;
			time = _timeOut * 1000 / 100;
		}
		else if (_timeOut < 1000)
		{
			whileSize = 150;
			time = _timeOut * 1000 / 150;
		}
		else
		{
			whileSize = 180;
			time = _timeOut * 1000 / 180;
		}
		if (_timer)
			return false;
		_timer = new Timer(_loop);
		_wheel = new TimingWheel(whileSize);
		_timer.setTimerHandle(()nothrow{_wheel.prevWheel();});
		return _timer.start(time);
	}

private:
	//int[ClientConnection] _list;
	ClientConnection _list;
	LinkManger _waitConnect;

	shared PipeLineFactory _factory;
	TimingWheel _wheel;
	Timer _timer;
	EventLoop _loop;

	uint _tryCount;
	ClientCreatorCallBack _oncreator;
}

package:

final @trusted class ClientLink(PipeLine) : WheelTimer, PipelineManager
{
	alias ConnectionManger = ClientManger!PipeLine;

	pragma(inline, true) void initialize()
	{
		_pipe.transportActive();
	}

	pragma(inline, true) void close()
	{
		_pipe.transportInactive();
	}

	override void onTimeOut() nothrow
	{
		try{
			_pipe.timeOut();
		} catch (Exception e){
			showException(e);
		}
	}

	override void refreshTimeout() 
	{
		rest();
	}

	override void deletePipeline(PipelineBase pipeline)
	{
		pipeline.pipelineManager = null;
		stop();
		_manger.remove(this);
	}
protected:
	this(ConnectionManger manger, PipeLine pipe)
	{
		_manger = manger;
		_pipe = pipe;
		_pipe.finalize();
		_pipe.pipelineManager(this);
	}
private:
	this(){}
	ClientLink!PipeLine prev;
	ClientLink!PipeLine next;
private:
	ConnectionManger _manger;
	PipeLine _pipe;
	string _name;
}

package:
struct TLinkInfo(TCallBack) if(is(TCallBack == delegate))
{
	TcpStreamClient client;
	Address addr;
	uint tryCount = 0;
	TCallBack cback;
}