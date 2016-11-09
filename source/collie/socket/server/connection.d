module collie.socket.server.connection;

import collie.utils.timingwheel;
import collie.socket.tcpsocket;
import collie.socket.eventloop;

@trusted abstract class ServerConnection : WheelTimer
{
	this(TCPSocket socket)
	{
		restSocket(socket);
	}

	final void restSocket(TCPSocket socket)
	{
		if(_socket !is null){
			_socket.setCloseCallBack(null);
			_socket.setReadCallBack(null);
			_socket = null;
		}
		if(socket !is null){
			_socket = socket;
			_loop = socket.eventLoop;
			_socket.setCloseCallBack(&doClose);
			_socket.setReadCallBack(&onRead);
		}
	}

	final bool isAlive() @trusted {
		return _socket && _socket.isAlive;
	}

	final bool active() @trusted
	{
		if(_socket is null)
			return false;
		bool active  = _socket.start();
		if(active)
			onActive();
		return active;
	}

	final void write(ubyte[] data,TCPWriteCallBack cback = null) @trusted
	{
		_loop.post((){
					if(_socket) {
						rest();
						_socket.write(data, cback);
					}else if(cback)
						cback(data,0);
				});
	}

	final void restTimeout() @trusted
	{
		_loop.post((){rest();});
	}

	final void close() @trusted
	{
		_loop.post((){
				if(_socket)
					_socket.close();
			});
	}

	final @property tcpSocket()@safe {return _socket;}
protected:
	void onActive() nothrow;
	void onClose() nothrow;
	void onRead(ubyte[] data) nothrow;

private:
	final void doClose()
	{
		stop();
		onClose();
	}
private:
	TCPSocket _socket;
	EventLoop _loop;
}

