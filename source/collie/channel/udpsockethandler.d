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

module collie.channel.udpsockethandler;

/*
import std.socket;

import collie.net;
import collie.channel;

struct UdpData
{
	Address address;
	ubyte[] data;
}

class UdpSocketHandler : HandlerAdapter!(UdpData)
{
	this(UDPSocket sock)
	{
		_socket = sock;
	}

	override void transportActive(Context ctx) {
		_socket.setReadCallBack(&hasData);
		_socket.start();
		ctx.fireTransportActive();
	}

	override void transportInactive(Context ctx) {
		_socket.close();
		ctx.fireTransportInactive();
	}


	override void write(Context ctx,UdpData msg,TheCallBack cback) {
		auto leng = _socket.sendTo(msg.data, msg.address);
		if(cback)
			cback(msg,cast(size_t)leng);
	}

protected:
	void hasData(ubyte[] buffer, Address adr)
	{
		UdpData data;
		data.address = adr;
		data.data = buffer;
		context.fireRead(data);
	}

private:
	UDPSocket _socket;
}
*/