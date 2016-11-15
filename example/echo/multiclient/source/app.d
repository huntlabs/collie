/*
 * Collie - An asynchronous event-driven network framework using Dlang development
 *
 * Copyright (C) 2015-2016  Shanghai Putao Technology Co., Ltd 
 *
 * Developer: putao's Dlang team
 *
 * Licensed under the Apache-2.0 License.
 *
 */
module app;

import core.thread;

import std.datetime;
import std.stdio;
import std.functional;

import collie.socket;
import collie.channel;
import collie.bootstrap.clientmanger;

alias Pipeline!(ubyte[], ubyte[]) EchoPipeline;

ClientManger!EchoPipeline client;
EventLoop loop;

int num = 0;

class EchoHandler : HandlerAdapter!(ubyte[], ubyte[])
{
public:
	this(int nm)
	{
		import std.conv;
		_nm = to!string(nm);
	}
    override void read(Context ctx, ubyte[] msg)
    {
         writeln("Read data : ", cast(string) msg.dup, "   the length is ", msg.length);
    }

    void callBack(ubyte[] data, uint len)
    {
        writeln("\t writed data : ", cast(string) data, "   the length is ", len);
    }

    override void timeOut(Context ctx)
    {
        writeln("clent beat time Out!");
        string data = "NO." ~ _nm ~ "   \t" ~ Clock.currTime().toSimpleString();
        write(ctx, cast(ubyte[])data , &callBack);
    }
    
    override void transportInactive(Context ctx)
    {
        loop.stop();
    }

private:
	string _nm;
}

class EchoPipelineFactory : PipelineFactory!EchoPipeline
{
public:
    override EchoPipeline newPipeline(TCPSocket sock)
    {
        auto pipeline = EchoPipeline.create();
        pipeline.addBack(new TCPSocketHandler(sock));
		num ++;
		pipeline.addBack(new EchoHandler(num));
        pipeline.finalize();
        return pipeline;
    }
}


void main()
{
    loop = new EventLoop();
	client = new ClientManger!EchoPipeline(loop);

	client.tryCount(3);
	client.heartbeatTimeOut(2);
	client.pipelineFactory(new shared EchoPipelineFactory());
	client.connect(new InternetAddress("127.0.0.1",8094),(EchoPipeline pipe){
			if(pipe is null)
				writeln("connect erro! No. 1");
		});
	client.connect(new InternetAddress("127.0.0.1",8094),(EchoPipeline pipe){
			if(pipe is null)
				writeln("connect erro! No. 2");
		});
	client.connect(new InternetAddress("127.0.0.1",8094),(EchoPipeline pipe){
			if(pipe is null)
				writeln("connect erro! No. 3");
		});
	client.connect(new InternetAddress("127.0.0.1",8094),(EchoPipeline pipe){
			if(pipe is null)
				writeln("connect erro! No. 4");
		});
	client.connect(new InternetAddress("127.0.0.1",8094),(EchoPipeline pipe){
			if(pipe is null)
				writeln("connect erro! No. 5");
		});
	client.connect(new InternetAddress("127.0.0.1",8094),(EchoPipeline pipe){
			if(pipe is null)
				writeln("connect erro! No. 6");
		});
    loop.run();
    
    writeln("APP Stop!");
}
