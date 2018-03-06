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
module collie.bootstrap.client;

import collie.channel;
import collie.net;
import collie.utils.memory;

import collie.bootstrap.exception;
import collie.net.client.linkinfo;
public import kiss.net.TcpStream;
import kiss.event.task;

final class ClientBootstrap(PipeLine) : PipelineManager
{
	alias ConnCallBack = void delegate(PipeLine);
	alias LinkInfo = TLinkInfo!ConnCallBack;
	alias ClientCreatorCallBack = void delegate(TcpStream);

	this(EventLoop loop)
	{
		_loop = loop;
	}
	
	~this()
	{
		if (_timer)
			_timer.destroy;
		if(_info.client)
			_info.client.destroy;
	}

	void setClientCreatorCallBack(ClientCreatorCallBack cback)
	{
		_oncreator = cback;
	}
	
	auto pipelineFactory(shared PipelineFactory!PipeLine pipeFactory)
	{
		_pipelineFactory = pipeFactory;
		return this;
	}
	
	/// time is s
	auto heartbeatTimeOut(uint second)
	{
		_timeOut = second * 1000;
		return this;
	}

	void connect(Address to, ConnCallBack cback = null)
	{
		if (_pipelineFactory is null)
			throw new NeedPipeFactoryException(
				"Pipeline must be not null! Please set Pipeline frist!");
		if (_info.client)
			throw new ConnectedException("This Socket is Connected! Please close before connect!");
		_info.addr = to;
		_info.tryCount = 0;
		_info.cback = cback;
		_loop.postTask(newTask(&doConnect));
	}
	
	void close()
	{
		if (_info.client is null)
			return;
		_info.client.close();
	}
	
	@property EventLoop eventLoop()
	{
		return _loop;
	}
	
	@property auto pipeLine()
	{
		if(_info.client is null)
			return null;
		return _pipe;
	}

	@property tryCount(){return _tryCount;}
	@property tryCount(uint count){_tryCount = count;}

protected:
	void doConnect()
	{
		_info.client = new TcpStream(_loop,_info.addr.addressFamily);
		if(_oncreator)
			_oncreator(_info.client);
		_info.client.setCloseHandle(&closeCallBack);
		_info.client.setConnectHandle(&connectCallBack);
		_info.client.setReadHandle(&readCallBack);
		_info.client.connect(_info.addr);
	}

	void closeCallBack() nothrow @trusted
	{
		catchAndLogException((){
				if (_timer)
					_timer.stop();
				if(_pipe)
					_pipe.transportInactive();
			}());
	}
	
	void connectCallBack(bool isconnect) nothrow @trusted
	{
		catchAndLogException((){
			if (isconnect)
			{
				if (_timeOut > 0)
				{
					if (_timer is null)
					{
						trace("new timer!");
						_timer = new Timer(_loop);
						_timer.setTimerHandle(&onTimeOut);
					}
					if(!_timer.watched) {

						bool rv = _timer.start(_timeOut);
						trace("start timer!   : ", rv);
					}
				}
				_info.tryCount = 0;
				_pipe = _pipelineFactory.newPipeline(_info.client);
				if(_info.cback)
					_info.cback(_pipe);
				_pipe.finalize();
				_pipe.pipelineManager(this);
				_pipe.transportActive();
			}else if(_info.tryCount < _tryCount){
				_info.client = null;
				_info.tryCount ++;
				doConnect();
			} else {
				if(_info.cback)
					_info.cback(null);
				_info.client = null;
				_info.cback = null;
				_info.addr = null;
				_pipe = null;
			}
		}());
	}
	
	void readCallBack(in ubyte[] buffer) nothrow @trusted
	{
		catchAndLogException(_pipe.read(cast(ubyte[])buffer));
	}
	/// Client Time out is not refresh!
	void onTimeOut() nothrow @trusted
	{
		catchAndLogException((){
		if(_pipe)
			_pipe.timeOut();
			}());
	}
	
	override void deletePipeline(PipelineBase pipeline)
	{
		if (_timer)
			_timer.stop();
		gcFree(_info.client);
		_info.client = null;
		pipeline.pipelineManager(null);
		_pipe = null;
	}
	
	override void refreshTimeout()
	{
	}
	
private:
	EventLoop _loop;
	PipeLine _pipe;
	shared PipelineFactory!PipeLine _pipelineFactory;
	Timer _timer = null;
	uint _timeOut = 0;
	uint _tryCount;

	LinkInfo _info;
	ClientCreatorCallBack _oncreator;
}
