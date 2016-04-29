module app;

import core.thread;

import std.datetime;
import std.stdio;
import std.functional;

import collie.socket;
import collie.channel;
import collie.bootstrap.serverbootstrap;

alias Pipeline!(UniqueBuffer,ubyte[]) EchoPipeline;

ServerBootStrap!EchoPipeline ser;


class EchoHandler : HandlerAdapter!(UniqueBuffer,ubyte[]) 
{
public:
	override void read(Context ctx, UniqueBuffer msg) 
	{
		write(ctx,msg.data.dup,&callBack);
	}

	void callBack(ubyte[] data, uint len)
	{
		writeln("writed data : ", cast(string)data, "   the length is ",len);
	}
}

class EchoPipelineFactory : PipelineFactory!EchoPipeline
{
public:
	override EchoPipeline newPipeline(TCPSocket sock)
	{
		auto pipeline = EchoPipeline.create();
		pipeline.addBack(new TCPSocketHandler(sock));
		pipeline.addBack(new EchoHandler());
		pipeline.finalize();
		return pipeline;
	}
}

void main()
{
	ser  = new ServerBootStrap!EchoPipeline();
	ser.childPipeline(new EchoPipelineFactory()).bind(new InternetAddress("0.0.0.0",8094));
	ser.group(new EventLoopGroup);
	ser.waitForStop();

	writeln("APP Stop!");
}
