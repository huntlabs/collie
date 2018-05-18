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
module collie.net.client.clientmanger;

import std.socket;

import kiss.exception;
import kiss.event;
import kiss.util.timer;
import kiss.net.TcpStream;
import collie.net.client.linklogInfo;
import collie.net.client.exception;

import kiss.event.timer.common;
import kiss.event.task;
import kiss.util.functional;

final class TCPClientManger
{
	alias ClientCreatorCallBack = void delegate(TcpStream);
	alias ConCallBack = void delegate(ClientConnection);
	alias LinklogInfo = TLinklogInfo!ConCallBack;
	alias NewConnection = ClientConnection delegate(TcpStream);

	this(EventLoop loop)
	{
		_loop = loop;
	}

	void setClientCreatorCallBack(ClientCreatorCallBack cback)
	{
		_oncreator = cback;
	}

	void setNewConnectionCallBack(NewConnection cback)
	{
		_cback = cback;
	}

	@property eventLoop(){return _loop;}
	@property timeout(){return _timeout;}
	@property tryCout(){return _tryCout;}
	@property tryCout(uint count){_tryCout = count;}

	void startTimeout(uint s)
	{
		if(_wheel !is null)
			throw new SocketClientException("TimeOut is runing!");
		_timeout = s;
		if(_timeout == 0 || _timer)
			return;
		
		uint whileSize;uint time; 
		enum int[] fvka = [40,120,600,1000,uint.max];
		enum int[] fvkb = [50,60,100,150,300];
		foreach(i ; 0..fvka.length ){
			if(s <= fvka[i]){
				whileSize = fvkb[i];
				time = _timeout * 1000 / whileSize;
				break;
			}
		}
		
		_wheel = new TimingWheel(whileSize);
		_timer = new KissTimer(_loop, time);
		_timer.onTick(&onTimer);
		if(_loop.isInLoopThread()){
			_timer.start();
		} else {
			_loop.postTask(newTask(&_timer.start, false, false));
		}
	}

	void connect(Address addr,ConCallBack cback = null)
	{
		if(_cback is null)
			throw new SocketClientException("must set NewConnection callback ");
		LinklogInfo * logInfo = new LinklogInfo();
		logInfo.addr = addr;
		logInfo.tryCount = 0;
		logInfo.cback = cback;
		if(_loop.isInLoopThread()){
			_postConmnect(logInfo);
		} else {
			_loop.postTask(newTask(&_postConmnect,logInfo));
		}
	}

	void stopTimer(){
		if(_timer) {
			_timer.stop();
			_timer = null;
		}
	}

protected:
	void connect(LinklogInfo * logInfo)
	{
		logInfo.client = new TcpStream(_loop);
		if(_oncreator)
			_oncreator(logInfo.client);
		logInfo.client.onClosed(&tmpCloseCallBack);
		logInfo.client.onConnected(bind(&connectCallBack,logInfo));
		// logInfo.client.setReadHandle(&tmpReadCallBack);
		logInfo.client.connect(logInfo.addr);
	}

	void tmpReadCallBack(in ubyte[]) nothrow {}
	void tmpCloseCallBack() {}

	void connectCallBack(LinklogInfo * logInfo,bool state) 
	{
		catchAndLogException((){
			import std.exception;
			if(logInfo is null)return;
			if(state) {
				scope(exit){
					_waitConnect.rmlogInfo(logInfo);
				}
				ClientConnection con;
				collectException(_cback(logInfo.client),con);
				if(logInfo.cback)
					logInfo.cback(con);
				if(con is null) return;
				if(_wheel)
					_wheel.addNewTimer(con);
				con.onActive();
			} else {
				logInfo.client = null;
				if(logInfo.tryCount < _tryCout) {
					logInfo.tryCount ++;
					connect(logInfo);
				} else {
					auto cback = logInfo.cback;
					_waitConnect.rmlogInfo(logInfo);
					if(cback)
						cback(null);
				}
			}
		}());
	}

	void onTimer(Object ){
		_wheel.prevWheel();
	}

private:
	final void _postConmnect(LinklogInfo * logInfo){
		_waitConnect.addlogInfo(logInfo);
		connect(logInfo);
	}
private:
	uint _tryCout = 1;
	uint _timeout;

	EventLoop _loop;
	KissTimer _timer;
	TimingWheel _wheel;
	TLinkManger!ConCallBack _waitConnect;

	NewConnection _cback;
	ClientCreatorCallBack _oncreator;
}

@trusted abstract class ClientConnection : WheelTimer
{
	this(TcpStream client)
	{
		resetClient(client);
	}

	final bool isAlive() @trusted {
		return _client && _client.isRegistered;
	}

	final @property tcpClient()@safe {return _client;}

	alias restClient = resetClient;

	final void resetClient(TcpStream client) @trusted
	{
		if(_client !is null){
			_client.onClosed(null);
			_client.onDataReceived(null);
			_client.onConnected(null);
			_client = null;
		}
		if(client !is null){
			_client = client;
			_loop = cast(EventLoop) client.eventLoop;
			_client.onClosed(&doClose);
			_client.onDataReceived(&onRead);
			_client.onConnected(&tmpConnectCallBack);
		}
	}

	final void write(in ubyte[] data, DataWrittenHandler cback = null) @trusted
	{
		write(new SocketStreamBuffer(data,cback));
	}

	final void write(StreamWriteBuffer buffer) @trusted
    {
        if (_loop.isInLoopThread()) {
            _postWriteBuffer(buffer);
        } else {
            _loop.postTask(newTask(&_postWriteBuffer, buffer));
        }
    }

	final void restTimeout() @trusted
	{
		if(_loop.isInLoopThread()){
			rest();
		} else {
			_loop.postTask(newTask(&rest,0));
		}
	}

	pragma(inline)
	final void close() @trusted
	{
		_loop.postTask(newTask(&_postClose));
	}
protected:
	void onActive() nothrow;
	void onClose() nothrow;
	void onRead(in ubyte[] data) nothrow;
private:
	final void tmpConnectCallBack(bool) nothrow{}
	final void doClose() @trusted nothrow
	{
		catchAndLogException((){
			stop();
			onClose();
		}());
	}

	final void _postClose(){
		if(_client)
			_client.close();
	}

    final void _postWriteBuffer(StreamWriteBuffer buffer)
    {
        if (_client) {
            rest();
            _client.write(buffer);
        } else
            buffer.doFinish();
    }

private:
	TcpStream _client;
	EventLoop _loop;
}
