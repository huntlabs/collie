module collie.socket.client.clientmanger;

import std.socket;

import collie.socket.eventloop;
import collie.socket.timer;
import collie.socket.tcpclient;
import collie.socket.tcpsocket;
import collie.socket.client.linkinfo;
import collie.socket.client.exception;

import collie.utils.timingwheel;
import collie.utils.memory;

@trusted final class TCPClientManger
{
	alias ClientCreatorCallBack = void delegate(TCPClient);
	alias ConCallBack = void delegate(ClientConnection);
	alias LinkInfo = TLinkInfo!ConCallBack;
	alias NewConnection = ClientConnection delegate(TCPClient);

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
		if (_timeout <= 40)
		{
			whileSize = 50;
			time = _timeout * 1000 / 50;
		}
		else if (_timeout <= 120)
		{
			whileSize = 60;
			time = _timeout * 1000 / 60;
		}
		else if (_timeout <= 600)
		{
			whileSize = 100;
			time = _timeout * 1000 / 100;
		}
		else if (_timeout < 1000)
		{
			whileSize = 150;
			time = _timeout * 1000 / 150;
		}
		else
		{
			whileSize = 180;
			time = _timeout * 1000 / 180;
		}
		
		_wheel = new TimingWheel(whileSize);
		_timer = new Timer(_loop);
		_timer.setCallBack(&onTimer);
		_loop.post((){ _timer.start(time);});
	}

	void connect(Address addr,ConCallBack cback = null)
	{
		if(_cback is null)
			throw new SocketClientException("must set NewConnection callback ");
		LinkInfo * info = new LinkInfo();
		info.addr = addr;
		info.tryCount = 0;
		info.cback = cback;
		_loop.post((){
				_waitConnect.addInfo(info);
				connect(info);
			});
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
		info.client = new TCPClient(_loop);
		if(_oncreator)
			_oncreator(info.client);
		info.client.setCloseCallBack(&tmpCloseCallBack);
		info.client.setConnectCallBack(bind(&connectCallBack,info));
		info.client.setReadCallBack(&tmpReadCallBack);
		info.client.connect(info.addr);
	}

	void tmpReadCallBack(ubyte[]){}
	void tmpCloseCallBack(){}

	void connectCallBack(LinkInfo * info,bool state)
	{
		import std.exception;
		if(info is null)return;
		if(state) {
			scope(exit){
				_waitConnect.rmInfo(info);
				gcFree(info);
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
			gcFree(info.client);
			if(info.tryCount < _tryCout) {
				info.tryCount ++;
				connect(info);
			} else {
				auto cback = info.cback;
				_waitConnect.rmInfo(info);
				gcFree(info);
				if(cback)
					cback(null);
			}
		}
	}

	void onTimer(){
		_wheel.prevWheel();
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
	this(TCPClient client)
	{
		restClient(client);
	}

	final bool isAlive() @trusted {
		return _client && _client.isAlive;
	}

	final @property tcpClient()@safe {return _client;}

	final void restClient(TCPClient client) @trusted
	{
		if(_client !is null){
			_client.setCloseCallBack(null);
			_client.setReadCallBack(null);
			_client.setConnectCallBack(null);
			_client = null;
		}
		if(client !is null){
			_client = client;
			_loop = client.eventLoop;
			_client.setCloseCallBack(&doClose);
			_client.setReadCallBack(&onRead);
			_client.setConnectCallBack(&tmpConnectCallBack);
		}
	}

	final void write(ubyte[] data,TCPWriteCallBack cback = null) @trusted
	{
		_loop.post((){
				if(_client)
					_client.write(data, cback);
				else if(cback)
					cback(data,0);
			});
	}

	final void close() @trusted
	{
		_loop.post((){
				if(_client)
					_client.close();
			});
	}

protected:
	void onActive() nothrow;
	void onClose() nothrow;
	void onRead(ubyte[] data) nothrow;
private:
	final void tmpConnectCallBack(bool){}
	final void doClose() @trusted
	{
		stop();
		onClose();
	}
private:
	TCPClient _client;
	EventLoop _loop;
}
