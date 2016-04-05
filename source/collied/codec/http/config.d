module collied.codec.http.config;

import collied.codec.http.handler;
import collied.channel.pipeline;
public import std.datetime;

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

	__gshared static uint Max_Body_Size = 8*1024*1024;//2M
	__gshared static uint Max_Header_Size = 16 * 1024;//8K;
	__gshared static Duration httpTimeOut = 20.seconds;
	uint Header_Stection_Size = 1024;
	uint REQ_Body_Stection_Size = 4096;
	uint REP_Body_Stection_Size = 4096;


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
