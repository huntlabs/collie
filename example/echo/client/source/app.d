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
import std.exception;

import collie.socket;
import collie.channel;
import collie.bootstrap.client;

EventLoopGroup group;

alias Pipeline!(ubyte[], ubyte[]) EchoPipeline;
class EchoHandler : HandlerAdapter!(ubyte[], ubyte[])
{
public:
    override void read(Context ctx, ubyte[] msg){
         writeln("Read data : ", cast(string) msg.dup, "   the length is ", msg.length);
    }

    void callBack(ubyte[] data, uint len){
        writeln("\t writed data : ", cast(string) data, "   the length is ", len);
    }

    override void timeOut(Context ctx){
        writeln("clent beat time Out!");
        string data = Clock.currTime().toSimpleString();
        write(ctx, cast(ubyte[])data , &callBack);
    }
    
    override void transportInactive(Context ctx){
		group.stop();
    }
}

class EchoPipelineFactory : PipelineFactory!EchoPipeline
{
public:
    override EchoPipeline newPipeline(TCPSocket sock){
        auto pipeline = EchoPipeline.create();
        pipeline.addBack(new TCPSocketHandler(sock));
        pipeline.addBack(new EchoHandler());
        pipeline.finalize();
        return pipeline;
    }
}

void waitForConnect(Address addr,ClientBootstrap!EchoPipeline client)
{
	writeln("waitForConnect");
	import core.sync.semaphore;
	Semaphore cod = new Semaphore(0);
	client.connect(addr,(EchoPipeline pipe){
			if(pipe)
				writeln("connect suesss!");
			else
				writeln("connect erro!");
			cod.notify();});
	cod.wait();
	enforce(client.pipeLine,"can not connet to server!");
}


void main()
{
	group = new EventLoopGroup(1);
	group.start();
	ClientBootstrap!EchoPipeline client = new ClientBootstrap!EchoPipeline(group.at(0));
	client.tryCount(3);
	client.heartbeatTimeOut(2)
		.pipelineFactory(new shared EchoPipelineFactory());
	waitForConnect(new InternetAddress("127.0.0.1",8094),client);
    
        auto pipe = client.pipeLine();
        while(true)
	{
		writeln("write to send server: ");
		string data = readln();
		pipe.write(cast(ubyte[])data,null);
	}
}
