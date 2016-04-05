
version (EXEc):

import core.thread;
import std.stdio;
import collied.channel;
import collied.handler.basehandler;
import collied.booststrap.server;
import std.parallelism;
import core.runtime;
import std.conv;
import core.memory;
import collied.codec.http;
import std.container.array;

import std.experimental.allocator.mallocator ;
import std.experimental.allocator.building_blocks.free_list ;

debug { 
	extern(C) __gshared string[] rt_options = [ "gcopt=profile:1"];// maxPoolSize:50" ];
}
/*
static this()
{
	threadColliedAllocator = allocatorObject(FreeList!(AlignedMallocator,1024)());
}
*/
void httphandler(HTTPRequest req ,HTTPResponse rep)
{
	rep.header.setHeaderValue("content-type","text/html;charset=UTF-8");
	version(NO_KeepLive) {
		rep.header.setHeaderValue("Connection","close");
	}
	/*if(req.header.method == HTTPMethod.HTTP_POST){
		writeln("post data : ", cast(string)(req.HTTPBody.readAll()));
		auto from = new WebForm(req);
		if(from.isVaild) {
			auto forms = from.formMap();
			foreach(key,value;forms){
				writeln("key = ",key,"  value = ", value);
			}
			auto files = from.fileMap();
			foreach(key,value;files){
				writeln("key = ",key,"  file.name = ", value.fileName);
				auto buffer = req.HTTPBody();
				buffer.rest(value.startSize);
				buffer.read(value.length,delegate(in ubyte[] data){
						writeln("\t file data = ",cast(string)data);
					});
			}
			
		} else {
			writeln("from erro!");
		}
	}*/
	rep.HTTPBody.write(cast(ubyte[])"hello wrold!");
	rep.sent();
}

void main(string[] args)
{
	globalLogLevel(LogLevel.error);

	writeln("current cpus = ",totalCPUs,"\n");
	writeln("args : port threads threadMode");
	writeln("like : ./Collied 9005 4 0 \n");
	//string[] args = Runtime.args;
	ushort port = 9005;
	uint threads = 4;
	if(args.length == 3) {
		writeln(args);
		port = to!ushort(args[1]);
		threads = to!uint(args[2]);
		if(port == 0  || threads ==0 ){
			writeln("Args Erro!");
			return;
		}
	}
	HTTPConfig.instance.doHttpHandle = toDelegate(&httphandler);
	HTTPConfig.instance.doWebSocket = toDelegate(&EchoWebSocket.newEcho);
	HTTPConfig.instance.Header_Stection_Size = 256;
	HTTPConfig.instance.REP_Body_Stection_Size = 1024;
	HTTPConfig.instance.REQ_Body_Stection_Size = 1024;
	HTTPConfig.instance.httpTimeOut = 20.seconds;
	auto loop = new EventLoop();
	version (SSL) {
		auto server = new SSLServerBoostStarp(loop);
		writeln("start ! The Port is ",port, "  Threads is ",threads);
		server.setPrivateKeyFile("server.pem");
		server.setCertificateFile("server.pem");
	} else {
		auto server = new ServerBoostStarp(loop);
		writeln("start ! The Port is ",port, "  Threads is ",threads);
	}
	debug {
		Timer tm = new Timer(loop);
		tm.TimeOut = dur!"seconds"(30);
		tm.once = true;
		tm.setCallBack(delegate(){writeln("close time out : ");tm.kill();server.stop();});
		tm.start();
	}
	server.setPipelineFactory(toDelegate(&HTTPConfig.createPipline)).setThreadSize(threads)
		.bind(Address("0.0.0.0",port)).run();
}




class EchoWebSocket : WebSocket
{
	override void onClose()
	{
		writeln("websocket closed");
	}

	override void onTextFrame(Frame frame)
	{
		writeln("get a text frame, is finna : ", frame.isFinalFrame, "  data is :", cast(string)frame.data);
		sendText("456789");
	//	sendBinary(cast(ubyte[])"456123");
	//	ping(cast(ubyte[])"123");
	}

	override void onPongFrame(Frame frame)
	{
		writeln("get a text frame, is finna : ", frame.isFinalFrame, "  data is :", cast(string)frame.data);
	}

	override void onBinaryFrame(Frame frame)
	{
		writeln("get a text frame, is finna : ", frame.isFinalFrame, "  data is :", cast(string)frame.data);
	}

	static WebSocket newEcho(const HTTPHeader header)
	{
		trace("new EchoWebSocket ");
		return new EchoWebSocket;
	}
}