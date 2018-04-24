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
import collie.net.client.linklogInfo;
public import kiss.net.TcpStream;
import kiss.event.task;

final class ClientBootstrap(PipeLine) : PipelineManager
{
	alias ConnCallBack = void delegate(PipeLine);
	alias LinklogInfo = TLinklogInfo!ConnCallBack;
	alias ClientCreatorCallBack = void delegate(TcpStream);

	this(EventLoop loop)
	{
		_loop = loop;
	}
	
	~this()
	{
		if (_timer)
			_timer.destroy;
		if(_logInfo.client)
			_logInfo.client.destroy;
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
		if (_logInfo.client)
			throw new ConnectedException("This Socket is Connected! Please close before connect!");
		_logInfo.addr = to;
		_logInfo.tryCount = 0;
		_logInfo.cback = cback;
		_loop.postTask(newTask(&doConnect));
	}
	
	void close()
	{
		if (_logInfo.client is null)
			return;
		_logInfo.client.close();
	}
	
	@property EventLoop eventLoop()
	{
		return _loop;
	}
	
	@property auto pipeLine()
	{
		if(_logInfo.client is null)
			return null;
		return _pipe;
	}

	@property tryCount(){return _tryCount;}
	@property tryCount(uint count){_tryCount = count;}

protected:
	void doConnect()
	{
		_logInfo.client = new TcpStream(_loop,_logInfo.addr.addressFamily);
		if(_oncreator)
			_oncreator(_logInfo.client);
		_logInfo.client.setCloseHandle(&closeCallBack);
		_logInfo.client.setConnectHandle(&connectCallBack);
		_logInfo.client.setReadHandle(&readCallBack);
		_logInfo.client.connect(_logInfo.addr);
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
						logDebug("new timer!");
						_timer = new KissTimer(_loop);
						_timer.setTimerHandle(&onTimeOut);
					}
					if(!_timer.watched) {

						bool rv = _timer.start(_timeOut);
						logDebug("start timer!   : ", rv);
					}
				}
				_logInfo.tryCount = 0;
				_pipe = _pipelineFactory.newPipeline(_logInfo.client);
				if(_logInfo.cback)
					_logInfo.cback(_pipe);
				_pipe.finalize();
				_pipe.pipelineManager(this);
				_pipe.transportActive();
			}else if(_logInfo.tryCount < _tryCount){
				_logInfo.client = null;
				_logInfo.tryCount ++;
				doConnect();
			} else {
				if(_logInfo.cback)
					_logInfo.cback(null);
				_logInfo.client = null;
				_logInfo.cback = null;
				_logInfo.addr = null;
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
		gcFree(_logInfo.client);
		_logInfo.client = null;
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
	KissTimer _timer = null;
	uint _timeOut = 0;
	uint _tryCount;

	LinklogInfo _logInfo;
	ClientCreatorCallBack _oncreator;
}
