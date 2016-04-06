

import core.thread;
import std.stdio;
import collie.channel;
import collie.handler.base;
import collie.booststrap.server;
import std.parallelism;
import core.runtime;
import std.conv;
import core.memory;
import collie.codec.http.http;
import collie.codec.http.utils.buffer;
import std.container.array;
import collie.codec.ptpack.ptpack;

extern(C) __gshared string[] rt_options = [ "gcopt=profile:0 incPoolSize:4" ];

final class EchoHandle : Handler
{
	this (PiPline pip) {super(pip);}

	override void inEvent(InEvent event){
            writeln("have new event :", event.type);
		if(event.type == DePackEvent.type) {
			scope auto ev = cast(DePackEvent) event;
			writeln("have event , data = " , ev.mdata);
			writeln("have event , type = " , ev.mtype);
			writeln("have event , lenght = " , ev.mlength);
			mixin(encodePack("ev.mdata.dup","ev.mtype","this.pipline","this"));
        } else {
			event.up();
		}

	}
}

void createPipline(PiPline pip){
     pip.pushHandle(new PtPack!(true)(pip));
	pip.pushHandle(new EchoHandle(pip));
}


void main()
{
	writeln("current cpus = ",totalCPUs);
	writeln("start echo server at port : 9009");
	ServerBoostStarp server = new ServerBoostStarp;
	server.setPiplineFactory(toDelegate(&createPipline))
		.setThreadSize(2)
		.bind(Address("0.0.0.0",9009)).run();
}
