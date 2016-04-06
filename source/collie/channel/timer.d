/* Copyright collied.org 
*/

module collie.channel.timer;

import core.sys.posix.time;
import core.sync.mutex;

public import std.datetime;

import collie.channel;
import collie.channel.channel;



//import core.sys.linux.timerfd;
/**
 *  定时器的封装
 * @authors : Putao‘s Collie Team
 * @date : 2016.1
*/



final class Timer : Channel
{
public :
	/** 构造函数。
	 * 	@param : loop = 所属的事件循环。
	 */
	this(EventLoop loop)
	{
		super(loop);
		type = CHANNEL_TYPE.Timer;
	}
	~this(){
		kill();//如果还在链接就释放，就会段错误，因为GC操作内存了
	}
	
	/** 超时时间设置的值。 */
	@property TimeOut(Duration time) {_time = time;}
	@property TimeOut() {return _time;}
	
	/** 定时器是否是只执行一次 */
	@property once() {return _runOnce;}
	@property once(bool isonce){_runOnce = isonce;}
	
	
	/**  重新设定定时器的时间。
	 *  @note : 如果是kill的，应调用start（）。 
	 */
	bool restart(Duration time) {
		if(this.isInValid()) return false;
		TimeOut = time;
		static if (IOMode == IO_MODE.epoll){

			itimerspec its;
			long sec,nsec;
			_time.split!("seconds", "nsecs")(sec,nsec);
			its.it_value.tv_sec = cast(typeof(its.it_value.tv_sec))sec;
			its.it_value.tv_nsec = cast(typeof(its.it_value.tv_nsec))nsec;
			if (!_runOnce) {
				its.it_interval.tv_sec = its.it_value.tv_sec;
				its.it_interval.tv_nsec = its.it_value.tv_nsec;
				
			}
			int err = timerfd_settime(fd, 0, &its, null);
			if(err == -1) return false;
			return true;
		} else static if(IOMode == IO_MODE.kqueue) {
			return eventLoop.addEvent(this);
		}
	}
	
	/** 设置回调。 
	 *  @param : callback = 时间到后的回调函数
	 */
	void setCallBack(CallBack callback){_callBack = callback;}
	
	/** 启动定时器。用于第一次启动或者kill后的启用。如果是一次性定时器超时，或者更改时间后的启用，请用restart函数 
	 */
	bool start(){
		if (!this.isInValid()) return false;
		static if (IOMode == IO_MODE.epoll){
			fd = timerfd_create(CLOCK_MONOTONIC, TFD_CLOEXEC|TFD_NONBLOCK);
			itimerspec its;
			long sec,nsec;
			_time.split!("seconds", "nsecs")(sec,nsec);
			its.it_value.tv_sec = cast(typeof(its.it_value.tv_sec))sec;
			its.it_value.tv_nsec = cast(typeof(its.it_value.tv_nsec))nsec;
			if (!_runOnce) {
				its.it_interval.tv_sec = its.it_value.tv_sec;
				its.it_interval.tv_nsec = its.it_value.tv_nsec;
				
			}
			int err = timerfd_settime(fd, 0, &its, null);
			if(err == -1) return false;
			return eventLoop.addEvent(this);
		} else static if(IOMode == IO_MODE.kqueue) {
			import collie.channel.selector.kqueue;
			fd = eventLoop.loop.createIndex();
			import std.stdio;
			writeln("timer fd = ", fd);
			return eventLoop.addEvent(this);
		}
	}
	
	/** 杀死定时器。 */
	void kill() {
		onClose();
	}

protected:
	/** 定时器到期调用的函数。
	 *  @note : 注意，如果您的超时很短，而处理很慢，则中间的超时可能会被忽略，保证同时只有一个处理在运行。
	 */
	override void onRead() {
		ulong value;
		read(fd, &value, 8);
		if(!_callBack) {
			kill();
			return;
		}
		static if(IOMode == IO_MODE.kqueue){
			if(once) {
				import collie.channel.selector.kqueue;
				eventLoop.loop.removeTimer(this);
			}
		}
		_callBack();
	}
	override void onWrite(){}
	/** 关闭定时器，并从事件循环里退出。 */
	override void onClose(){
		if (!this.isInValid()) 
			eventLoop.delEvent(this);
	}
private:
	Duration  _time;
	bool _runOnce;
	CallBack _callBack;
};
