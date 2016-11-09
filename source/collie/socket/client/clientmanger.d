module collie.socket.client.tcpclientmanger;

import std.socket;

import collie.socket.eventloop;
import collie.socket.timer;
import collie.socket.tcpclient;
import collie.socket.tcpsocket;
import collie.socket.client.linkinfo;
import collie.socket.client.connection;
import collie.socket.client.exception;

import collie.utils.timingwheel;
import collie.utils.memory;

final class TCPClientManger
{
	alias ConCallBack = void delegate(ClientConnection);
	alias LinkInfo = TLinkInfo!ConCallBack;
	alias NewConnection = ClientConnection delegate(TCPClient);

	this(EventLoop loop)
	{
		_loop = loop;
	}

	void setNewConnectionCallBack(NewConnection cback)
	{
		_cback = cback;
	}

	@property eventLoop(){return _loop;}
	@property timeout(){return _timeout;}
	@property tryCout(){return _tryCout;}
	@property tryCout(uint count){_tryCout = count;}

	bool startTimeout(uint s)
	{
		if(_wheel !is null)
			return false;
		_timeout = s;
		if(_timeout == 0)
			return false;
		
		uint whileSize;uint time; 
		if (_timeout == 0)
			return false;
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
		_timer.setCallBack((){_wheel.prevWheel();});
		return _timer.start(time);
	}

	void connect(Address addr,ConCallBack cback)
	{
		if(_cback is null)
			throw new SocketClientException("must set NewConnection callback ");
		LinkInfo * info = new LinkInfo();
		info.addr = addr;
		info.tryCount = 0;
		info.cback = cback;
		_waitConnect[info] = 0;
		connect(info);
	}

protected:
	void connect(LinkInfo * info)
	{
		import collie.utils.functional;
		info.client = new TCPClient(_loop);
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
				_waitConnect.remove(info);
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
				_waitConnect.remove(info);
				gcFree(info);
				if(cback)
					cback(null);
			}
		}
	}

private:
	uint _tryCout = 1;
	uint _timeout;

	EventLoop _loop;
	Timer _timer;
	TimingWheel _wheel;
	int[LinkInfo *] _waitConnect;

	NewConnection _cback;
}

abstract class ClientConnection : WheelTimer
{
	this(TCPClient client)
	{
		restClient(client);
	}
	final @property tcpClient(){return _client;}
	final void restClient(TCPClient client)
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

	final void write(ubyte[] data,TCPWriteCallBack cback)
	{
		_loop.post(delegate(){
				if(_client)
					_client.write(data, cback);
				else
					cback(data,0);
			});
	}

protected:
	void onActive() nothrow;
	void onClose() nothrow;
	void onRead(ubyte[] data) nothrow;
private:
	final void tmpConnectCallBack(bool){}
	final void doClose()
	{
		stop();
		onClose();
	}
private:
	TCPClient _client;
	EventLoop _loop;
}
