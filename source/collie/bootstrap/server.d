module collie.bootstrap.server;

//import std.container.rbtree;

import collie.socket;
import collie.channel;

final class ServerBootStrap(PipeLine)
{
    this()
    {
        _loop = new EventLoop();
    }

    this(EventLoop loop)
    {
        _loop = loop;
    }

    auto pipeline(AcceptPipelineFactory factory)
    {
        _acceptPipelineFactory = factory;
        return this;
    }

    /*	auto acceptorConfig(const ServerSocketConfig accConfig) {
	 _accConfig = accConfig;
	 return this;
	 } */

    auto childPipeline(PipelineFactory!PipeLine factory)
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
        auto accept = new Accept(loop, _address.addressFamily == AddressFamily.INET6);
        accept.reusePort = _rusePort;
        accept.bind(_address);
        accept.listen(128);
        AcceptPipeline pipe;
        if (_acceptPipelineFactory)
            pipe = _acceptPipelineFactory.newPipeline(accept);
        else
            pipe = AcceptPipeline.create();
        return new ServerAceptor!(PipeLine)(accept, pipe, _childPipelineFactory);
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
    AcceptPipelineFactory _acceptPipelineFactory;
    PipelineFactory!PipeLine _childPipelineFactory;

    ServerAceptor!(PipeLine) _mainAccept;
    EventLoop _loop;

    ServerAceptor!(PipeLine)[] _serverlist;
    EventLoopGroup _group;

    bool _runing = false;
    bool _rusePort = true;
    uint _timeOut = 0;
    Address _address;
}

private:

import std.functional;
import collie.utils.timingwheel;

final class ServerAceptor(PipeLine) : InboundHandler!(Socket)
{
    this(Accept accept, AcceptPipeline pipe, PipelineFactory!PipeLine clientPipeFactory)
    {
        _accept = accept;
        _pipeFactory = clientPipeFactory;
        pipe.addBack(this);
        pipe.finalize();
        _pipe = pipe;
        _pipe.transport(_accept);
        _accept.setCallBack(&acceptCallBack);
        //_list = new int[ServerConnection!PipeLine];//RedBlackTree!(ServerConnection!PipeLine)();
    }

    void initialize()
    {
        _pipe.transportActive();
    }

    void stop()
    {
        _pipe.transportInactive();
    }

    override void read(Context ctx, Socket msg)
    {
        auto asyntcp = new TCPSocket(_accept.eventLoop, msg);
        auto pipe = _pipeFactory.newPipeline(asyntcp);
        if (!pipe)
            return;
        pipe.finalize();
        auto con = new ServerConnection!PipeLine(pipe);
        con.serverAceptor = this;
        //_list.stableInsert(con);
        _list[con] = 0;
        con.initialize();
        if (_wheel)
            _wheel.addNewTimer(con);
    }

    override void transportActive(Context ctx)
    {
        _accept.start();
    }

    override void transportInactive(Context ctx)
    {
        _accept.close();
        foreach (con, value; _list)
        {
            con.close();
            con.stop();
        }
        _list.clear();
        _accept.eventLoop.stop();
    }

    void remove(ServerConnection!PipeLine conn)
    {
        conn.stop();
        _list.remove(conn);
    }

    void acceptCallBack(Socket soct)
    {
        _pipe.read(soct);
    }

    @property acceptor()
    {
        return _accept;
    }

    void startTimingWhile(uint whileSize, uint time)
    {
        if (_timer)
            return;
        _timer = new Timer(_accept.eventLoop);
        _timer.setCallBack(&doWheel);
        _wheel = new TimingWheel(whileSize);
        _timer.start(time);
    }

protected:
    void doWheel()
    {
        if (_wheel)
            _wheel.prevWheel();
    }

private:
    int[ServerConnection!PipeLine] _list;
    //RedBlackTree!(ServerConnection!PipeLine) _list;
    Accept _accept;
    Timer _timer;
    TimingWheel _wheel;
    AcceptPipeline _pipe;
    PipelineFactory!PipeLine _pipeFactory;
}

final class ServerConnection(PipeLine) : WheelTimer, PipelineManager
{
    this(PipeLine pipe)
    {
        _pipe = pipe;
        _pipe.pipelineManager = this;
    }

    void initialize()
    {
        _pipe.transportActive();
    }

    void close()
    {
        _pipe.transportInactive();
    }

    @property serverAceptor()
    {
        return _manger;
    }

    @property serverAceptor(ServerAceptor!PipeLine manger)
    {
        _manger = manger;
    }

    override void deletePipeline(PipelineBase pipeline)
    {
        _manger.remove(this);
        pipeline.pipelineManager = null;
        _pipe = null;
        _manger = null;
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
    ServerAceptor!PipeLine _manger;
    PipeLine _pipe;
}
