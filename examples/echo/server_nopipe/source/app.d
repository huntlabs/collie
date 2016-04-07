import std.stdio;
import collie.channel;
import std.container.rbtree;
import std.functional;

int[Client] list;

class Client
{
	this(TCPSocket tcp)
	{
		tcp.readHandler(&onRead);
		tcp.writeHandler(&onWrite);
		tcp.colsedHandler(&onClose);
		tcp.statusHandler(&onState);
		fd = tcp.fd;
		this.tcp = tcp;
	}

protected:
	void onRead(ubyte[] data)
	{
		writeln("fd = ", fd, "  read size :", data.length);
		tcp.write(data.dup);
	}

	void onWrite(ubyte[] data, uint writeLenght )
	{
		writeln("fd = ", fd, "  write size :", writeLenght, "  data length", data.length);
	}

	void onState(SOCKET_STATUS sfrom,SOCKET_STATUS sto)
	{
		writeln(fd,"  tcp status from :", sfrom, "   changed to :", sto);
	}

	void onClose(ubyte[][] data)
	{
		writeln(fd,"  closed! ", data.length, " data do not send!");
		list.remove(this);
	}
private:
	TCPSocket tcp;
	int fd;
}

void newClient(TCPSocket tcp)
{
	auto client = new Client(tcp);
	list[client] = tcp.fd;
	tcp.start();
}

void main()
{
	writeln("Edit source/app.d to start your project.");

	EventLoop loop = new EventLoop();

	TCPListener listen = new TCPListener(loop);

	listen.setConnectHandler(toDelegate(&newClient));
	writeln("listen  port : 9009");
	listen.listen(Address("0.0.0.0",9009));
	bool run = true;
	loop.run();
}
