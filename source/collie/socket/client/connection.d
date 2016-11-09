module collie.socket.client.connection;

import collie.utils.timingwheel;
import collie.socket.tcpclient;

abstract class ClientConnection : WheelTimer
{
	this(TCPClient client)
	{
		// Constructor code
	}
	@property tcpClient(){return _client;}
	void restClient(TCPClient client)
	{}
protected:
	void onActive() nothrow;
	void onClose() nothrow;
	void onRead(ubyte[] data) nothrow;
private:
	TCPClient _client;
}

