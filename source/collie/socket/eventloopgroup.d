module collie.socket.eventloopgroup;

import core.thread;
import std.parallelism;
import std.container.array;

import collie.socket.eventloop;
import collie.socket.common;

class EventLoopGroup
{
	this(uint size = (totalCPUs - 1))
	{
            foreach(i;0..size){
                _loops.insertBack(new EventLoop);
            }
	}
	
	void start()
	{
            for(int i; i < _loops.length; ++i){
                auto loop = _loops[i];
                _group.create(cast(CallBack)(&loop.run));
            }
            _started = true;
	}
	
	void stop()
	{
            for(int i; i < _loops.length; ++i){
                _loops[i].stop();
            }
            _started = false;
            wait();
	}

	@property length(){ return _loops.length;}
	
	void addEventLoop(EventLoop loop)
	{
            _loops.insertBack(loop);
            if(_started)
                _group.create(cast(CallBack)(&loop.run));
	}
	
	void post(uint index, CallBack cback)
	{
            at(index).post(cback);
	}
	
	EventLoop opIndex(size_t index)
	{
           return at(index);
	}
	
	EventLoop at(size_t index)
	{
            auto i = index  / cast(uint)_loops.length;
            return _loops[i];
	}
	
	void wait()
	{
            _group.joinAll();
	}

private :
	bool _started;
	Array!(EventLoop) _loops;
	ThreadGroup _group;
}
