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
import std.experimental.logger;

import collie.socket;
import collie.channel;
import collie.bootstrap.server;

alias Pipeline!(ubyte[], ubyte[]) EchoPipeline;

ServerBootstrap!EchoPipeline ser;

class EchoHandler : HandlerAdapter!(ubyte[], ubyte[])
{
public:
    override void read(Context ctx, ubyte[] msg){
        write(ctx,msg.dup, &callBack);
    }

    void callBack(ubyte[] data, size_t len){
        writeln("writed data : ", cast(string) data, "   the length is ", len);
    }

    override void timeOut(Context ctx){
        writeln("Sever beat time Out!");
    }
}

shared class EchoPipelineFactory : PipelineFactory!EchoPipeline
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

void main()
{
    ser = new ServerBootstrap!EchoPipeline();
    ser.childPipeline(new EchoPipelineFactory()).heartbeatTimeOut(5)
        .group(new EventLoopGroup).bind(8094);
    ser.waitForStop();

    writeln("APP Stop!");
}
