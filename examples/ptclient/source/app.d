import core.thread;
import std.stdio;
import collie.channel;
import collie.handler.base;
import collie.booststrap.client;
import std.parallelism;
import core.runtime;
import std.conv;
import core.memory;
import collie.codec.http.http;
import collie.codec.http.utils.buffer;
import std.container.array;
import collie.codec.ptpack.ptpack;

ClientBoostStarp client;
static this()
{
    client = new ClientBoostStarp();
}
final class EchoHandle : Handler
{
	this (PiPline pip) {super(pip);}

	override void inEvent(InEvent event){
                writeln("have new event :", event.type);
		if(event.type == DePackEvent.type) {
                        ++i;
			if(i > 5) {
                           mixin(closeChannel("this.pipline","this"));
                            client.stop();
                            return;
			}
			scope auto ev = cast(DePackEvent) event;
			writeln("have event , data = " , ev.mdata);
			writeln("have event , type = " , ev.mtype);
			writeln("have event , lenght = " , ev.mlength);
			mixin(encodePack("ev.mdata.dup","ev.mtype","this.pipline","this"));
                } else if (event.type == INEVENT_CONNECT) {
                 //   scope auto wev = new EnPackEvent(this.pipline,this);
                    ubyte[] data = ['0','0','0','0','0'];
                /*    wev.mdata = data;
                    wev.mtype = 22;*/
                    writeln("write event , data = " , data);
                    mixin(encodePack("data","22","this.pipline","this"));
		}  else {
			event.up();
		}

	}
    int i = 0;
}

void main()
{
        client.pushHandle(new PtPack!(true)(client.pipline));
	client.pushHandle(new EchoHandle(client.pipline));
	writeln("start connect!");
	if(client.connect(Address("127.0.0.1",9009))){
           client.run(); 
	} else {
            writeln("connect erro!");
	}
	 writeln("run over!");
}
