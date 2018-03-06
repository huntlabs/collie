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

import kiss.event;
import kiss.net.Timer;
import kiss.net.TcpStream;
import collie.net.client.linkinfo;
import collie.net.client.exception;

import kiss.timingwheel;
//import collie.utils.memory;
import kiss.event.task;

@trusted final class TCPClientManger
{
	alias ClientCreatorCallBack = void delegate(TcpStream);
	alias ConCallBack = void delegate(ClientConnection);
	alias LinkInfo = TLinkInfo!ConCallBack;
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
		_timer = new Timer(_loop);
		_timer.setTimerHandle(&onTimer);
		if(_loop.isInLoopThread()){
			_timer.start(time);
		} else {
			_loop.postTask(newTask(&_timer.start,time));
		}
	}

	void connect(Address addr,ConCallBack cback = null)
	{
		if(_cback is null)
			throw new SocketClientException("must set NewConnection callback ");
		LinkInfo * info = new LinkInfo();
		info.addr = addr;
		info.tryCount = 0;
		info.cback = cback;
		if(_loop.isInLoopThread()){
			_postConmnect(info);
		} else {
			_loop.postTask(newTask(&_postConmnect,info));
		}
	}

	void stopTimer(){
		if(_timer) {
			_timer.stop();
			_timer = null;
		}
	}

protected:
	void connect(LinkInfo * info)
	{
		import collie.utils.functional;
		info.client = new TcpStream(_loop);
		if(_oncreator)
			_oncreator(info.client);
		info.client.setCloseHandle(&tmpCloseCallBack);
		info.client.setConnectHandle(bind(&connectCallBack,info));
		info.client.setReadHandle(&tmpReadCallBack);
		info.client.connect(info.addr);
	}

	void tmpReadCallBack(in ubyte[]) nothrow {}
	void tmpCloseCallBack() nothrow {}

	void connectCallBack(LinkInfo * info,bool state) nothrow
	{
		catchAndLogException((){
			import std.exception;
			if(info is null)return;
			if(state) {
				scope(exit){
					_waitConnect.rmInfo(info);
				}
				ClientConnection con;
				collectException(_cback(info.client),con);
				if(info.cback)
					info.cback(con);
				if(con is null) return;
				if(_wheel)
					_wheel.addNewTimer(con);
				con.onActive();
			} else {
				info.client = null;
				if(info.tryCount < _tryCout) {
					info.tryCount ++;
					connect(info);
				} else {
					auto cback = info.cback;
					_waitConnect.rmInfo(info);
					if(cback)
						cback(null);
				}
			}
		}());
	}

	void onTimer() nothrow{
		_wheel.prevWheel();
	}

private:
	final void _postConmnect(LinkInfo * info){
		_waitConnect.addInfo(info);
		connect(info);
	}
private:
	uint _tryCout = 1;
	uint _timeout;

	EventLoop _loop;
	Timer _timer;
	TimingWheel _wheel;
	TLinkManger!ConCallBack _waitConnect;

	NewConnection _cback;
	ClientCreatorCallBack _oncreator;
}

@trusted abstract class ClientConnection : WheelTimer
{
	this(TcpStream client)
	{
		restClient(client);
	}

	final bool isAlive() @trusted {
		return _client && _client.watched;
	}

	final @property tcpClient()@safe {return _client;}

	final void restClient(TcpStream client) @trusted
	{
		if(_client !is null){
			_client.setCloseHandle(null);
			_client.setReadHandle(null);
			_client.setConnectHandle(null);
			_client = null;
		}
		if(client !is null){
			_client = client;
			_loop = client.eventLoop;
			_client.setCloseHandle(&doClose);
			_client.setReadHandle(&onRead);
			_client.setConnectHandle(&tmpConnectCallBack);
		}
	}

	final void write(ubyte[] data,TCPWriteCallBack cback = null) @trusted
	{
		write(new WarpStreamBuffer(data,cback));
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
