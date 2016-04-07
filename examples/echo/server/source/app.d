

import core.thread;
import std.stdio;
import collie.channel;
import collie.handler.base;
import collie.booststrap.server;
import std.parallelism;
import core.runtime;
import std.conv;
import core.memory;
import std.container.array;
import collie.codec.utils.cutpack;

extern(C) __gshared string[] rt_options = [ "gcopt=profile:0 incPoolSize:4" ];

final class EchoHandle : Handler
{
	this (PiPeline pip) {super(pip);}

	override void inEvent(InEvent event){
            writeln("have new event :", event.type);
		if(event.type == InCutPackEvent.type) {
			scope auto ev = cast(InCutPackEvent) event;
			writeln("have event , data = " , ev.data);
			writeln("have event , lenght = " , ev.data.length);
			mixin(enCutPack("ev.data.dup","this.pipeline","this"));
        } else {
			event.up();
		}

	}
}

void createPipeline(PiPeline pip){
  //      pip.pushHandle(new CutPack!(true)(pip));
	pip.pushHandle(new EchoHandle(pip));
}

void main()
{
	writeln("current cpus = ",totalCPUs);
	writeln("start echo server at port : 9009");
	ServerBoostStarp server = new ServerBoostStarp;
	server.setPipelineFactory(toDelegate(&createPipeline))
		.setThreadSize(2)
		.bind(Address("0.0.0.0",9009)).run();
}

