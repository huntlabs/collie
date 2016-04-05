import core.thread;
import std.stdio;
import channel;
import handler.basehandler;
import booststrap.client;
import std.parallelism;
import codec.cutpack.cutpack;
import channel.address;

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
		if(event.type == InCutPackEvent.type) {
                        ++i;
			if(i > 5) {
                            scope auto wev = new OutEventClose(event.pipline);
                            wev.down();
                            client.stop();
                            return;
			}
			scope auto ev = cast(InCutPackEvent) event;
			scope auto wev = new OutCutPackEvent(this.pipline,this);
			wev.data = ev.data.dup;
			logInfo("have event , data = " , wev.data);
			wev.down();
                } else if (event.type == INEVENT_CONNECT) {
                    scope auto wev = new OutCutPackEvent(this.pipline,this);
                    ubyte[] data = ['0','0','0','0','0'];
                    wev.data = data;
                    logInfo("write event , data = " , wev.data);
                    wev.down();
		} else if(event.type == INEVENT_WRITE) {
			scope auto ev = cast(INEventWrite) event;
			logInfo("write sesson :",ev.size);
		} else {
			event.up();
		}

	}
    int i = 0;
}

void main()
{
        client.pushHandle(new CutPack(client.pipline));
	client.pushHandle(new EchoHandle(client.pipline));
	writeln("start connect!");
	if(client.connect(Address("127.0.0.1",9009))){
           client.run(); 
	} else {
            writeln("connect erro!");
	}
	 writeln("run over!");
}