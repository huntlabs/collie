/* Copyright collied.org 
 */

module collied.channel.eventloop;

import collied.channel;

import core.thread;
import core.sync.mutex;
import core.memory;
public import std.concurrency;
import core.thread;
import std.datetime;
import std.variant;
import std.algorithm.mutation;
import core.sync.mutex;
import std.stdio;
import std.string;
import collied.channel.utils.queue;

/** 网络I/O处理的事件循环类
 @authors  Putao‘s Collie Team
 @date  2016.1
 */
 
class EventLoopImpl(T) if (is(T == class)) //用定义别名的方式
{
	this(){
		_poll = new T();
		_callbackList = SqQueue!(CallBack,true,false)(32);
		_mutex = new Mutex();
		_run = false;
	}
	~this(){
		_poll.destroy;
	}

	/** 开始执行事件等待。
	 @param :timeout = 无事件的超时等待时间。单位：毫秒
	 @note : 此函数可以多线程同时执行，实现多个线程共用一个事件调度。

	 */
	void run (int timeout = 100)
	{
		_th = Thread.getThis;
		_run = true;
		while(_run) {
			_poll.wait(timeout);
			if(!_callbackList.empty){
				doHandleList();
			}
		}
		_th = null;
		_run = false;
	}

	//@property Channel[int] channelList(){return _channelList;}
	void weakUp(){
		_poll.weakUp();
	}


	bool isRuning(){
		return _run;
	}


	void stop(){
		if(isRuning()){
			_run = false;
			weakUp();
		}
	}

	bool isInLoopThread(){
		if(!isRuning())return true;
		return _th == Thread.getThis;
	}

	Thread runingThread(){
		return _th;
	}

	void post(CallBack cback)
	{
		if(isInLoopThread()){
			cback();
			return;
		} else {
			synchronized(_mutex){
				_callbackList.enQueue(cback);
			}
		}
	}
package:
	/**
	 * 添加TcpSocket对象
	 */
	bool addEvent (Channel socket){
		return _poll.addEvent(socket);
	}
	/**
	 * del TcpSocket对象
	 */

	bool delEvent (Channel socket){
		return _poll.delEvent(socket);
	}

	@property T loop(){return _poll;}

protected:
	void doHandleList()
	{
		import std.algorithm : swap;
		auto tmp = SqQueue!(CallBack,true,false)(32);
		synchronized(_mutex){
			swap(tmp,_callbackList);
		}
		while(!tmp.empty){
			auto fp = tmp.deQueue(null);
			fp();
		}
	}

private:
	T _poll;
	Mutex _mutex;
	SqQueue!(CallBack,true,false)  _callbackList;
	bool _run;
	Thread _th;
};

enum IO_MODE {
	epoll,
	kqueue,
	iocp,
	select,
	poll,
	none
}



version (FreeBSD) 
{
	public import collied.channel.selector.kqueue;
	alias EventLoop = EventLoopImpl!(KqueueLoop);
	enum IO_MODE IOMode = IO_MODE.kqueue;
}
else version (OpenBSD) 
{
	public import collied.channel.selector.kqueue;
	alias EventLoop = EventLoopImpl!(KqueueLoop);
	enum IO_MODE IOMode = IO_MODE.kqueue;
}
else version (NetBSD)
{
	public import collied.channel.selector.kqueue;
	alias EventLoop = EventLoopImpl!(KqueueLoop);
	enum IO_MODE IOMode = IO_MODE.kqueue;
}
else version (OSX) 
{
	public import collied.channel.selector.kqueue;
	alias EventLoop = EventLoopImpl!(KqueueLoop);
	enum IO_MODE IOMode = IO_MODE.kqueue;
}
else version (Solaris)
{
	public import collied.channel.selector.port;
}
else version (linux) 
{
	public import collied.channel.selector.epoll;
	alias EventLoop = EventLoopImpl!(EpollLoop);
	enum IO_MODE IOMode = IO_MODE.epoll;
}
else version (Posix) 
{
	public import collied.channel.selector.poll;
}
else
{
	public import collied.channel.selector.select;
}
