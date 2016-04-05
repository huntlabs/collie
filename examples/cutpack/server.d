import core.thread;
import std.stdio;
import channel;
import handler.basehandler;
import booststrap.server;
import std.parallelism;
import codec.cutpack.cutpack;

final class EchoHandle : Handler
{
	this (PiPline pip) {super(pip);}

	override void inEvent(InEvent event){
            writeln("have new event :", event.type);
		if(event.type == InCutPackEvent.type) {
			scope auto ev = cast(InCutPackEvent) event;
			scope auto wev = new OutCutPackEvent(this.pipline,this);
			wev.data = ev.data.dup;
			logInfo("have event , data = " , wev.data);
			wev.down();
                } else if(event.type == INEVENT_WRITE) {
			scope auto ev = cast(INEventWrite) event;
			logInfo("write sesson :",ev.size);
		} else {
			event.up();
		}

	}
}

void createPipline(PiPline pip){
        pip.pushHandle(new CutPack(pip));
	pip.pushHandle(new EchoHandle(pip));
	return pip;
}


void main()
{
	writeln("current cpus = ",totalCPUs);
	writeln("start echo server at port : 9009");
	ServerBoostStarp server = new ServerBoostStarp;
	server.setPiplineFactory(toDelegate(&createPipline)).setMode(Server_IO_Mode.One_EventLoop)
		.setThreadSize(2)
		.bind(Address("0.0.0.0",9009)).run();
}