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
import collie.channel.utils.memory;
import std.container.array;

extern(C) __gshared string[] rt_options = [ "gcopt=profile:0 incPoolSize:4" ];

final class EchoHandle : Handler
{
	this (PiPline pip) {super(pip);}
	
	override void inEvent(InEvent event){
		if(event.type == INEVENT_TCP_READ) {
			import core.stdc.string : memcpy;
			scope auto wev = new OutEventTCPWrite(this.pipline,this);
			
			scope auto ev = cast( INEventTCPRead) event;
			wev.data = CAllocator.newArray!ubyte(ev.data.length);//ev.data.dup;
			memcpy(wev.data.ptr,ev.data.ptr,ev.data.length);
			info("have event , data = " , wev.data);
			wev.down();
			
		} else if(event.type == INEVENT_WRITE) {
			scope auto ev = cast(INEventWrite) event;
			CAllocator.deallocate(ev.data);
			info("write sesson :",ev.data.length);
		} else {
			event.up();
		}
		
	}
}

void createPipline(PiPline pip){
	
	pip.pushHandle(new EchoHandle(pip));
}

void main()
{
	writeln("current cpus = ",totalCPUs,"\n");
	writeln("args : port threads");
	writeln("like : ./Collied 9005 4 \n");
	string[] args = Runtime.args;
	ushort port = 9005;
	uint threads = 4;
	if(args.length == 4) {
		writeln(args);
		port = to!ushort(args[1]);
		threads = to!uint(args[2]);
		uint m = to!uint(args[3]);

		if(port == 0 || threads ==0 ){
			writeln("Args Erro!");
			return;
		}
	}
	ServerBoostStarp server = new ServerBoostStarp;
	writeln("start ! The Port is ",port, "  Threads is ",threads);
	server.setPiplineFactory(toDelegate(&createPipline)).setThreadSize(threads)
		.bind(Address("0.0.0.0",port)).run();
}

