import core.thread;
import std.stdio;
import collie.channel;
import collie.handler.base;
import collie.booststrap.client;
import std.parallelism;
import core.runtime;
import std.conv;
import core.memory;
import collie.codec.http;
import collie.codec.http.utils.buffer;
import std.container.array;
import collie.codec.utils.cutpack;

ClientBoostStarp client;
static this()
{
    client = new ClientBoostStarp();
}
final class EchoHandle : Handler
{
	this (PiPeline pip) {super(pip);}

	override void inEvent(InEvent event){
                writeln("have new event :", event.type);
		if(event.type == InCutPackEvent.type) {
                        ++i;
			if(i > 5) {
                           mixin(closeChannel("this.pipeline","this"));
                            client.stop();
                            return;
			}
			scope auto ev = cast(InCutPackEvent) event;
			writeln("have event , data = " , ev.data);
			writeln("have event , length = " , ev.data.length);
			mixin(enCutPack("ev.data.dup","this.pipeline","this"));
                } else if (event.type == INEVENT_STATUS_CHANGED) {
                    scope auto wev = cast(INEventSocketStatusChanged) event;
                    if(wev.status_to == SOCKET_STATUS.CONNECTED) {
                        ubyte[] data = ['0','0','0','0','0'];
                        writeln("write event , data = " , data);
                        mixin(enCutPack("data","this.pipeline","this"));
                    }
		}  else {
			event.up();
		}

	}
    int i = 0;
}

void main()
{
//        client.pushHandle(new CutPack!(true)(client.pipeline));
	client.pushHandle(new EchoHandle(client.pipeline));
	writeln("start connect!");
	if(client.connect(Address("127.0.0.1",9009))){
           client.run(); 
	} else {
            writeln("connect erro!");
	}
	 writeln("run over!");
}
