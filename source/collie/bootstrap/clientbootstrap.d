module collie.bootstrap.clientbootstrap;

import collie.socket;
import collie.channel;

import collie.channel.pipeline;
import collie.socket.tcpclient;

final class ClientBootStrap(PipeLine)
{
    this(EventLoop loop)
    {
        _loop = loop;
    }

private:
    EventLoop _loop;
    Pipeline!(PipeLine) _pipe;
    TCPClient _socket;
}
