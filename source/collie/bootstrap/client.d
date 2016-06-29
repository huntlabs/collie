/*
 * Collie - An asynchronous event-driven network framework using Dlang development
 *
 * Copyright (C) 2015-2016  Shanghai Putao Technology Co., Ltd 
 *
 * Developer: putao's Dlang team
 *
 * Licensed under the Apache-2.0 License.
 *
 */
module collie.bootstrap.client;

import std.socket;

import collie.socket;
import collie.channel;

//TODO: timer closed

final class ClientBootstrap(PipeLine) : PipelineManager
{
    this(EventLoop loop)
    {
        _loop = loop;
    }

    ~this()
    {
        if (_timer)
            _timer.destroy;
        _socket.destroy;
    }

    auto setPipelineFactory(shared PipelineFactory!PipeLine pipeFactory)
    {
        _pipelineFactory = pipeFactory;
        return this;
    }

    /// time is s
    auto heartbeatTimeOut(uint second)
    {
        _timeOut = second * 1000;
        return this;
    }

    void connect(string ip, ushort port)
    {
        connect(new InternetAddress(ip, port));
    }

    void connect(Address to)
    {

        if (_pipelineFactory is null)
            throw new NeedPipeFactoryException(
                "Pipeline must be not null! Please set Pipeline frist!");
        if (_socket is null)
            _socket = new TCPClient(_loop, (to.addressFamily() == AddressFamily.INET6));
        if (_socket.isAlive())
            throw new ConnectedException("This Socket is Connected! Please close before connect!");
        if (_pipe is null)
        {
            _pipe = _pipelineFactory.newPipeline(_socket);
            _pipe.finalize();
        }

        _socket.setCloseCallBack(&closeCallBack);
        _socket.setConnectCallBack(&connectCallBack);
        _socket.setReadCallBack(&readCallBack);
        _socket.connect(to);
    }

    void close()
    {
        if (_socket is null)
            return;
        _socket.close();
    }

    @property EventLoop eventLoop()
    {
        return _loop;
    }

    @property pipeLine()
    {
        return _pipe;
    }

protected:
    void closeCallBack()
    {
        if (_timer)
            _timer.stop();
        _pipe.transportInactive();
    }

    void connectCallBack(bool isconnect)
    {
        trace("connectCallBack ", isconnect);
        if (!isconnect)
        {
            trace("how!");
            _pipe.transportInactive();
            return;
        }
		_pipe.pipelineManager(this);
        _pipe.transportActive();
        if (_timeOut > 0)
        {
            if (_timer is null)
            {
                _timer = new Timer(_loop);
                _timer.setCallBack(&timeOut);
            }
			if(!_timer.isActive())
				_timer.start(_timeOut);
        }

    }

    void readCallBack(ubyte[] buffer)
    {
        _pipe.read(buffer);
    }
	/// Client Time out is not refresh!
    void timeOut()
    {
        _pipe.timeOut();
    }

	override void deletePipeline(PipelineBase pipeline)
	{
		if (_timer)
			_timer.stop();
		pipeline.pipelineManager(null);
	}

	override void refreshTimeout()
	{

	}

private:
    EventLoop _loop;
    PipeLine _pipe;
    shared PipelineFactory!PipeLine _pipelineFactory;
    TCPClient _socket;
    Timer _timer;
    uint _timeOut = 0;
}

class NeedPipeFactoryException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}
