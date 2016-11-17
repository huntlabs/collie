module collie.socket.client.linkinfo;


import std.socket;
import collie.socket.tcpclient;

struct TLinkInfo(TCallBack) if(is(TCallBack == delegate))
{
	TCPClient client;
	Address addr;
	uint tryCount = 0;
	TCallBack cback;
}