import std.stdio;

import std.socket;
import std.conv;

import collie.socket.udpsocket;
import collie.socket.eventloop;

void main()
{
   
   EventLoop loop = new EventLoop();
    
    UDPSocket server = new UDPSocket(loop);
    UDPSocket client = new UDPSocket(loop);
    
    server.bind(new InternetAddress("127.0.0.1", 9008));
    Address adr = new InternetAddress("127.0.0.1", 9008);
  
    
    int i = 0;
    
    void serverHandle(ubyte[] data, Address adr2)
    {
        string tstr = cast(string)data;
        writeln("Server revec data : ", tstr);
        string str = "hello " ~ i.to!string();
        server.sendTo(data,adr2);
        assert(str == tstr);
        if(i > 10)
            loop.stop();
    }
    
    void clientHandle(ubyte[] data, Address adr23)
    {
        writeln("Client revec data : ", cast(string)data);
        ++i;
        string str = "hello " ~ i.to!string();
        client.sendTo(str);
    }
    client.setReadCallBack(&clientHandle);
    server.setReadCallBack(&serverHandle);
    
    client.start();
    server.start();
    
    client.connect(adr);
    string str = "hello " ~ i.to!string();
    client.sendTo(cast(ubyte[])str);
    writeln("Edit source/app.d to start your project.");
    loop.run();
    server.close();
    client.close();
}
