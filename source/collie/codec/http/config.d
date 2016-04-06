module collie.codec.http.config;

public import std.datetime;

import collie.codec.http.handler;
import collie.channel.pipeline;

alias DoHttpHandle = void delegate (HTTPRequest,HTTPResponse);
alias DoWebSocket  = WebSocket delegate(const HTTPHeader header);

final class HTTPConfig
{
	static @property HTTPConfig instance()
	{
		if(_gconfig is null) {
			_gconfig = new HTTPConfig();
		}
		return _gconfig;
	}

	__gshared static uint MaxBodySize = 8*1024*1024;//2M
	__gshared static uint MaxHeaderSize = 16 * 1024;//8K;
	__gshared static Duration httpTimeOut = 20.seconds;
	uint HeaderStectionSize = 1024;
	uint RequestBodyStectionSize = 4096;
	uint ResponseBodyStectionSize = 4096;


	static void createPipline(PiPeline pip){
		pip.pushHandle(new HTTPHandle(pip,httpTimeOut));
	}

	@property doHttpHandle(DoHttpHandle handle){doHandle = handle;}
	@property doHttpHandle(){return doHandle;}
	@property doWebSocket(DoWebSocket handle){doSocket = handle;}
	@property doWebSocket(){return doSocket;}
private:
	this(){}
	__gshared static HTTPConfig _gconfig;
	DoHttpHandle doHandle;
	DoWebSocket doSocket;
}
