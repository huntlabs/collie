module collie.channel.tcpsockethandler;

import collie.buffer.uniquebuffer;
import collie.socket;
import collie.channel.handler;
import collie.channel.handlercontext;

class TCPSocketHandler : HandlerAdapter!(UniqueBuffer,ubyte[])
{
	//alias TheCallBack = void delegate(ubyte[],uint);
	//alias HandleContext!(UniqueBuffer, ubyte[]) Context;

	this(TCPSocket sock)
	{
		_socket = sock;
	}

	override void transportActive(Context ctx) {
		attachReadCallback();
		_socket.start();
		ctx.fireTransportActive();
	}

	override void transportInactive(Context ctx) {
		_socket.close();
	}

	override void write(Context ctx, ubyte[] msg, TheCallBack cback) {
		_socket.write(msg,cback);
	}

	override void close(Context ctx) {
		_socket.close();
	}

protected:
	void attachReadCallback()
	{
		_socket.setReadCallBack(&readCallBack);
		_socket.setCloseCallBack(&closeCallBack);
	}

	void closeCallBack()
	{
		getContext().fireTransportInactive();
		getContext().pipeline.deletePipeline();
	}

	void readCallBack(UniqueBuffer buf)
	{
		getContext().fireRead(buf);
	}

private:
	TCPSocket _socket;
}
