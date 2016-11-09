module collie.socket.client.client;

import std.socket;

import collie.socket.eventloop;
import collie.socket.timer;
import collie.socket.tcpclient;
import collie.socket.tcpsocket;
import collie.socket.client.exception;

abstract class BaseClient
{
	alias OnTcpClientCreator = void delegate(TCPClient);

	this(EventLoop loop)
	{
		_loop = loop;
	}

	final bool isActive()
	{
		return _client && _client.isAlive;
	}

	final void setTimeout(uint s)
	{
		_timeout = s;
	}

	final void connect(Address addr,OnTcpClientCreator cback)
	{
		if(isActive)
			throw new SocketClientException("must set NewConnection callback ");
		_client = new TCPClient(_loop);
		if(cback)
			cback(_client);
		_client.setConnectCallBack(&connectCallBack);
		_client.setCloseCallBack(&onClose);
		_client.setReadCallBack(&onRead);
		_client.connect(addr);
	}


	final void write(ubyte[] data,TCPWriteCallBack cback)
	{
		if(_client is null){
			cback(data,0);
			return;
		}
		_loop.post(delegate(){
				if(_client)
					_client.write(data, cback);
				else
					cback(data,0);
			});
	}
	
	final void close()
	{
		if(_client is null) return;
		_loop.post(delegate(){
				if(_client)
					_client.close();
			});
	}

protected:
	void onActive() nothrow;
	void onClose() nothrow;
	void onRead(ubyte[] data) nothrow;
	void onTimeout() nothrow;

	final startTimer()
	{
		if(_timeout == 0)
			return;
		if(_timer)
			_timer.stop();
		else {
			_timer = new Timer(_loop);
			_timer.setCallBack(&onTimeout);
		}
		_timer.start(_timeout * 1000);
	}
private:
	final void connectCallBack(bool state){
		if(state){
			onActive();
		} else {
			doClose();
		}

	}
	final void doClose()
	{
		import collie.utils.memory;
		if(_timer)
			_timer.stop();
		gcFree(_client);
		_client = null;
		onClose();
	}
private
	EventLoop _loop;
	TCPClient _client;
	Timer _timer;
	uint _timeout;
}

