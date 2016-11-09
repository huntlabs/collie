module collie.socket.server.connection;

import collie.utils.timingwheel;
import collie.socket.tcpsocket;
import collie.socket.eventloop;

abstract class ServerConnection : WheelTimer
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

	final bool active()
	{
		if(_socket is null)
			return false;
		bool active  = _socket.start();
		if(active)
			onActive();
		return active;
	}

	final void write(ubyte[] data,TCPWriteCallBack cback)
	{
		_loop.post(delegate(){
					if(_socket)
						_socket.write(data, cback);
					else
						cback(data,0);
				});
	}

	final @property tcpSocket(){return _socket;}
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

