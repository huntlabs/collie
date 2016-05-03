module collie.bootstrap.client;

import std.socket;

import collie.socket;
import collie.channel;

final class ClientBootStrap(PipeLine)
{
    this(EventLoop loop)
    {
        _loop = loop;
    }

    auto setPipelineFactory(PipelineFactory!PipeLine  pipeFactory)
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
        connect(new InternetAddress(ip,port));
    }
    
    void connect(Address to)
    {
        
        if(_pipelineFactory is null) throw new NeedPipeFactoryException("Pipeline must be not null! Please set Pipeline frist!");
        if(_socket is null) _socket = new TCPClient(_loop,(to.addressFamily() == AddressFamily.INET6));
         if (_socket.isConnect)
            throw new ConnectedException("This Socket is Connected! Please close before connect!");
        if(_pipe is null) 
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
        if (_socket is null) return;
            _socket.close();
    }
    
    @property EventLoop eventLoop(){return _loop;}
    @property pipeLine() {return _pipe;}
    
protected:
    void closeCallBack()
    {
        if(_timer) _timer.stop();
        _pipe.transportInactive();
    }
    
    void connectCallBack(bool isconnect)
    {
        if(!isconnect)
        {
             _pipe.transportInactive();
             return;
        }
        
        _pipe.transportActive();
        if(_timeOut > 0) 
        {
            if(_timer is null)
            { 
                _timer = new Timer(_loop);
                _timer.setCallBack(&timeOut);
            }
            _timer.start(_timeOut);
        }
        
    }
    
    void readCallBack(UniqueBuffer buffer)
    {
        _pipe.read(buffer);
    }

    void timeOut()
    {
        _pipe.timeOut();
    }
    
private:
    EventLoop _loop;
    PipeLine _pipe;
    PipelineFactory!PipeLine _pipelineFactory;
    TCPClient _socket;
    Timer _timer;
    uint _timeOut = 0;
}


class NeedPipeFactoryException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg,file,line);
    }
}
