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
import collie.bootstrap.client;

alias Pipeline!(ubyte[], ubyte[]) EchoPipeline;

ClientBootstrap!EchoPipeline client;
EventLoop loop;

class EchoHandler : HandlerAdapter!(ubyte[], ubyte[])
{
public:
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
        string data = Clock.currTime().toSimpleString();
        write(ctx, cast(ubyte[])data , &callBack);
    }
    
    override void transportInactive(Context ctx)
    {
        loop.stop();
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
    loop = new EventLoop();
    client = new ClientBootstrap!EchoPipeline(loop);
    client.heartbeatTimeOut(2).setPipelineFactory(new EchoPipelineFactory()).connect("127.0.0.1",8094);
    loop.run();
    
    writeln("APP Stop!");
}
