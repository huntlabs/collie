module collie.socket.sslsocket;

import std.socket;

import collie.socket.eventloop;
import collie.socket.common;
import collie.socket.tcpsocket;

final class SSLSocket : TCPSocket
{
    this(EventLoop loop, Socket sock)
    {
        super(loop, sock);
    }

protected:
    override void onClose()
    {
    }

    override void onWrite()
    {
    }

    override void onRead()
    {
    }

private:

}
