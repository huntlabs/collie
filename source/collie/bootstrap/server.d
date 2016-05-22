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
module collie.bootstrap.server;

import collie.socket;
import collie.channel;
import collie.bootstrap.serversslconfig;

import std.stdio;

final class ServerBootstrap(PipeLine)
{
    this()
    {
        _loop = new EventLoop();
    }

    this(EventLoop loop)
    {
        _loop = loop;
    }

    auto pipeline(shared AcceptPipelineFactory factory)
    {
        _acceptorPipelineFactory = factory;
        return this;
    }

    auto setSSLConfig(ServerSSLConfig config) 
    {
        _sslConfig = config;
        return this;
    } 

    auto childPipeline(shared PipelineFactory!PipeLine factory)
    {
        _childPipelineFactory = factory;
        return this;
    }

    auto group(EventLoopGroup group)
    {
        _group = group;
        return this;
    }

    auto setReusePort(bool ruse)
    {
        _rusePort = ruse;
        return this;
    }

    /**
            The Value will be 0 or 5s ~ 1800s.
            0 is disable, 
            if(value < 5) value = 5;
            if(value > 3000) value = 1800;
        */
    auto heartbeatTimeOut(uint second)
    {
        _timeOut = second;
        _timeOut = _timeOut < 5 ? 5 : _timeOut;
        _timeOut = _timeOut > 1800 ? 1800 : _timeOut;

        return this;
    }

    void bind(Address addr)
    {
        _address = addr;
    }

    void bind(ushort port)
    {
        _address = new InternetAddress(port);
    }

    void bind(string ip, ushort port)
    {
        _address = new InternetAddress(ip, port);
    }

    void stop()
    {
        if (!_runing)
            return;
        foreach (ref accept; _serverlist)
        {
            accept.stop();
        }
        _mainAccept.stop();
        join();
        _loop.stop();
        _runing = false;
    }

    void join()
    {
        if (!_runing)
            return;
        if (_group)
            _group.wait();
    }

    void waitForStop()
    {
        if (_runing)
            return;
        if (_address is null || _childPipelineFactory is null)
            return;
        _runing = true;
        uint wheel, time;
        bool beat = getTimeWheelConfig(wheel, time);
        _mainAccept = creatorAcceptor(_loop);
        _mainAccept.initialize();
        if (beat)
        {
            _mainAccept.startTimingWhile(wheel, time);
        }
        if (_group)
        {
            foreach (loop; _group)
            {
                auto acceptor = creatorAcceptor(loop);
                acceptor.initialize();
                _serverlist ~= acceptor;
                if (beat)
                {
                    acceptor.startTimingWhile(wheel, time);
                }
            }
            _group.start();
        }
        _loop.run();
    }

protected:
    auto creatorAcceptor(EventLoop loop)
    {
        auto acceptor = new Acceptor(loop, _address.addressFamily == AddressFamily.INET6);
        acceptor.reusePort = _rusePort;
        acceptor.bind(_address);
        acceptor.listen(1024);
        AcceptPipeline pipe;
        if (_acceptorPipelineFactory)
            pipe = _acceptorPipelineFactory.newPipeline(acceptor);
        else
            pipe = AcceptPipeline.create();
        SSL_CTX * ctx = null;

        if(_sslConfig)
        {
            ctx = _sslConfig.generateSSLCtx();
            if(!ctx) throw new Exception("Can not gengrate SSL_CTX");
        }

        return new ServerAcceptor!(PipeLine)(acceptor, pipe, _childPipelineFactory,ctx);
    }

    bool getTimeWheelConfig(out uint whileSize, out uint time)
    {
        if (_timeOut == 0)
            return false;
        if (_timeOut <= 40)
        {
            whileSize = 40;
            time = _timeOut * 1000 / 50;
        }
        else if (_timeOut <= 120)
        {
            whileSize = 60;
            time = _timeOut * 1000 / 60;
        }
        else if (_timeOut <= 600)
        {
            whileSize = 100;
            time = _timeOut * 1000 / 100;
        }
        else if (_timeOut < 1000)
        {
            whileSize = 150;
            time = _timeOut * 1000 / 150;
        }
        else
        {
            whileSize = 180;
            time = _timeOut * 1000 / 180;
        }
        return true;
    }

private:
    shared AcceptPipelineFactory _acceptorPipelineFactory;
    shared PipelineFactory!PipeLine _childPipelineFactory;

    ServerAcceptor!(PipeLine) _mainAccept;
    EventLoop _loop;

    ServerAcceptor!(PipeLine)[] _serverlist;
    EventLoopGroup _group;

    bool _runing = false;
    bool _rusePort = true;
    uint _timeOut = 0;
    Address _address;

    ServerSSLConfig _sslConfig = null;
}

private:

import std.functional;
import collie.utils.timingwheel;
import collie.utils.memory;

final class ServerAcceptor(PipeLine) : InboundHandler!(Socket)
{
    this(Acceptor acceptor, AcceptPipeline pipe,shared PipelineFactory!PipeLine clientPipeFactory, SSL_CTX * ctx = null)
    {
        _acceptor = acceptor;
        _pipeFactory = clientPipeFactory;
        pipe.addBack(this);
        pipe.finalize();
        _pipe = pipe;
        _pipe.transport(_acceptor);
        _acceptor.setCallBack(&acceptCallBack);
        _sslctx = ctx;
    }

    pragma(inline,true)
    void initialize()
    {
        _pipe.transportActive();
    }

    pragma(inline,true)
    void stop()
    {
        _pipe.transportInactive();
    }

    override void read(Context ctx, Socket msg)
    {

        if (_sslctx) 
        {
            auto ssl = SSL_new (_sslctx);
            if(SSL_set_fd(ssl, msg.handle()) < 0) {
                error("SSL_set_fd error: fd = ",msg.handle());
                SSL_shutdown (ssl);
                SSL_free(ssl);
                return ;
            }
            SSL_set_accept_state(ssl);
            auto asynssl = new SSLSocket(_acceptor.eventLoop,msg,ssl);
            auto shark = new SSLHandShark(asynssl,&doHandShark);
            _sharkList[shark] = 0;
            asynssl.start();
        } 
        else     
        {
            auto asyntcp = new TCPSocket(_acceptor.eventLoop, msg);
            startSocket(asyntcp);
        }
    }

    override void transportActive(Context ctx)
    {
        _acceptor.start();
    }

    override void transportInactive(Context ctx)
    {
        _acceptor.close();
        foreach (con, value; _list)
        {
            con.close();
            con.stop();
        }
        version(DigitalMars){
            _list.clear();
        } else {
            _list = null;
        }
        _acceptor.eventLoop.stop();
    }
protected:
    pragma(inline)
    void remove(ServerConnection!PipeLine conn)
    {
        _list.remove(conn);
        gcFree(conn);
    }

    void acceptCallBack(Socket soct)
    {
        _pipe.read(soct);
    }

    pragma(inline,true)
    @property acceptor()
    {
        return _acceptor;
    }

    void startTimingWhile(uint whileSize, uint time)
    {
        if (_timer)
            return;
        _timer = new Timer(_acceptor.eventLoop);
        _timer.setCallBack(&doWheel);
        _wheel = new TimingWheel(whileSize);
        _timer.start(time);
    }


    void doWheel()
    {
        if (_wheel)
            _wheel.prevWheel();
    }

    void doHandShark(SSLHandShark shark, SSLSocket sock)
    {
        _sharkList.remove(shark);
        scope(exit) delete shark;
        if(sock)
        {
            sock.setHandshakeCallBack(null);
            startSocket(sock);
        }
    }

    void startSocket(TCPSocket sock)
    {
        auto pipe = _pipeFactory.newPipeline(sock);
        if (!pipe) {
            gcFree(sock);
            return;
        }
        pipe.finalize();
        sock.deleteOnClosed(true);
        auto con = new ServerConnection!PipeLine(pipe);
        con.serverAceptor = this;
        _list[con] = 0;
        con.initialize();
        if (_wheel)
            _wheel.addNewTimer(con);
    }
private:
    int[ServerConnection!PipeLine] _list;
    int[SSLHandShark]  _sharkList;
    
    Acceptor _acceptor;
    Timer _timer;
    TimingWheel _wheel;
    AcceptPipeline _pipe;
    shared PipelineFactory!PipeLine _pipeFactory;
    
    SSL_CTX * _sslctx = null;
}

final class ServerConnection(PipeLine) : WheelTimer, PipelineManager
{
    this(PipeLine pipe)
    {
        _pipe = pipe;
        _pipe.pipelineManager = this;
    }
    ~this()
    {
        gcFree(_pipe);
    }

    pragma(inline,true)
    void initialize()
    {
        _pipe.transportActive();
    }

    pragma(inline,true)
    void close()
    {
        _pipe.transportInactive();
    }

    pragma(inline,true)
    @property serverAceptor()
    {
        return _manger;
    }

    pragma(inline,true)
    @property serverAceptor(ServerAcceptor!PipeLine manger)
    {
        _manger = manger;
    }

    override void deletePipeline(PipelineBase pipeline)
    {
        pipeline.pipelineManager = null;
        //_pipe = null;
        stop();
        _manger.remove(this);
    }

    override void refreshTimeout()
    {
        rest();
    }

    override void onTimeOut() nothrow
    {
        try
        {
            _pipe.timeOut();
        }
        catch
        {
        }
    }

private:
    ServerAcceptor!PipeLine _manger;
    PipeLine _pipe;
}

final class SSLHandShark
{
    alias SSLHandSharkCallBack = void delegate(SSLHandShark shark, SSLSocket sock);
    this(SSLSocket sock, SSLHandSharkCallBack cback)
    {
        _socket = sock;
        _cback = cback;
        _socket.setCloseCallBack(&onClose);
        _socket.setReadCallBack(&readCallBack);
        _socket.setHandshakeCallBack(&handSharkCallBack);
    }
    
    ~this()
    {
    }
protected:
    void handSharkCallBack()
    {
        trace("the ssl handshark over");
        _cback(this,_socket);
        _socket = null;
    }
    
    void readCallBack(ubyte[] buffer){}
    
    void onClose()
    {
        trace("the ssl handshark fail");
        _socket.setCloseCallBack(null);
        _socket.setReadCallBack(null);
        _socket.setHandshakeCallBack(null);
        _socket = null;
        _cback(this,_socket);
    }
private:
    SSLSocket _socket;
    SSLHandSharkCallBack _cback;
}
