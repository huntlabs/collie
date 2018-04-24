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
import kiss.event.timer.common;
import collie.utils.memory;
import kiss.util.functional;
import collie.exception;
import collie.utils.exception;
import collie.net.client.linklogInfo;
import std.exception;

public import kiss.net.TcpStream;
import kiss.event.task;

final class ClientManger(PipeLine)
{
	alias ClientConnection = ClientLink!PipeLine;
	alias PipeLineFactory = PipelineFactory!PipeLine;
	alias ClientCreatorCallBack = void delegate(TcpStream);
	alias ConnCallBack = void delegate(PipeLine);
	alias LinkManger = TLinkManger!ConnCallBack;
	alias LinklogInfo = LinkManger.LinklogInfo;

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
		LinklogInfo * tlogInfo = new LinklogInfo();
		tlogInfo.addr = to;
		tlogInfo.tryCount = 0;
		tlogInfo.cback = cback;
		_loop.postTask(newTask((){
				_waitConnect.addlogInfo(tlogInfo);
				connect(tlogInfo);
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
	void connect(LinklogInfo * logInfo)
	{
		logInfo.client = new TcpStream(_loop);
		if(_oncreator)
			_oncreator(logInfo.client);
		logInfo.client.setCloseHandle(&tmpCloseCallBack);
		logInfo.client.setConnectHandle(bind(&connectCallBack,logInfo));
		logInfo.client.setReadHandle(&tmpReadCallBack);
		logInfo.client.connect(logInfo.addr);
	}

	void connectCallBack(LinklogInfo * tlogInfo,bool isconnect) nothrow @trusted
	{
		catchAndLogException((){
		import std.exception;
		if(tlogInfo is null)return;
		if(isconnect){
			scope(exit){
				_waitConnect.rmlogInfo(tlogInfo);
			}
			PipeLine pipe = null;
			collectException(_factory.newPipeline(tlogInfo.client),pipe);
			if(tlogInfo.cback)
				tlogInfo.cback(pipe);
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
			tlogInfo.client = null;
			if(tlogInfo.tryCount < _tryCount) {
				tlogInfo.tryCount ++;
				connect(tlogInfo);
			}else{
				auto cback = tlogInfo.cback;
				_waitConnect.rmlogInfo(tlogInfo);
				gcFree(tlogInfo);
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
		_timer = new KissTimer(_loop);
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
	KissTimer _timer;
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
struct TLinklogInfo(TCallBack) if(is(TCallBack == delegate))
{
	TcpStream client;
	Address addr;
	uint tryCount = 0;
	TCallBack cback;
}