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

import collie.net;
import collie.channel;
import collie.bootstrap.client;

EventLoopGroup group;

alias EchoPipeline = Pipeline!(const(ubyte[]), StreamWriteBuffer);
class EchoHandler : HandlerAdapter!(const(ubyte[]), StreamWriteBuffer)
{
public:
    override void read(Context ctx, const(ubyte[]) msg){
         writeln("Read data : ", cast(string) msg.dup, "   the length is ", msg.length);
    }

    void callBack(const(ubyte[]) data, size_t len) @trusted nothrow{
        catchAndLogException((){
             writeln("writed data : ", cast(string) data, "   the length is ", len);
        }());
    }

    override void timeOut(Context ctx){
        writeln("clent beat time Out!");
        string data = Clock.currTime().toSimpleString();
        write(ctx,new SocketStreamBuffer(cast(const(ubyte)[])(data.dup),&callBack),null);
    }
    
    override void transportInactive(Context ctx){
		group.stop();
    }
}

class EchoPipelineFactory : PipelineFactory!EchoPipeline
{
public:
    override EchoPipeline newPipeline(TcpStream sock){
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
	client.heartbeatTimeOut(120)
		.pipelineFactory(new shared EchoPipelineFactory());
	waitForConnect(new InternetAddress("127.0.0.1",8094),client);
    
    auto pipe = client.pipeLine;
    while(true)
	{
		writeln("write to send server: ");
		string data = readln();
		pipe.write(new SocketStreamBuffer(cast(const(ubyte)[])(data),null),null);
	}
}
