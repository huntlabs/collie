module collie.booststrap.client;

import collie.channel.eventloop;
import collie.channel.pipeline;
import collie.channel.tcpsocket;
import collie.handler.basehandler;
import collie.channel.address;

final class ClientBoostStarp
{
	this(){
		auto loop = new EventLoop();
		this(loop);
	}
	this(EventLoop loop) {
		_loop = loop;
		_socket = new TCPSocket(_loop);
		_pip = new PiPeline(_socket);
	}

	ClientBoostStarp setOption(T)(TCPOption option, in T value)
	{
		_socket.setOption(option,value);
		return this;
	}

	bool connect(Address adr)
	{
		return _socket.connect(adr);
	}

	void pushHandle(Handler hand)
	{
		_pip.pushHandle(hand);
	}
	void pushInhandle(InHander handle)
	{
		_pip.pushInhandle(handle);
	}
	void pushOutHandle(OutHander handle)
	{
		_pip.pushOutHandle(handle);
	}

	void run()
	{
			_loop.run();
	}

	void close()
	{
		_socket.close();
	}

	void stop(){
		_loop.stop();
	}
	@property EventLoop eventloop(){return _loop;}
	@property PiPeline pipeline(){return _pip;}
private:
	PiPeline _pip;
	EventLoop _loop;
	TCPSocket _socket;
	bool _running;
};
