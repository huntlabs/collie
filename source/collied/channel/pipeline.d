
module collied.channel.pipeline;

import collied.channel;
import collied.handler.basehandler;
import core.sync.mutex;

import std.stdio;

/** 
 * 事件系统产生和传递管理类。 
 * 每一级都可以拦截和产生新的时间向上传递。
 * 时间分为入和出，入为下层传递到上层，出为上层传递到下层。
 * 
 */

string closeChannel(string pline, string handler)
{
	string str =  "{ scope auto mixins_event = new OutEventClose(" ~ pline ~ ", " ~ handler ~ ");
	mixins_event.down(); }";
	return str;
}

string closeChannel(string event)
{
	string str =  " {scope auto mixins_event = new OutEventClose(" ~ event ~ ");
	mixins_event.down(); }";
	return str;
}

string  writeChannel(string pline, string handler, string data)
{
	string str =  " {scope auto mixins_event = new OutEventTCPWrite(" ~ pline ~ ", " ~ handler ~ ");
	mixins_event.data = " ~ data ~ ";
	mixins_event.down(); }";
	return str;
}

string  writeChannel(string event, string data)
{
	string str =  " { scope auto mixins_event = new OutEventTCPWrite(" ~ event ~ ");
	mixins_event.data = " ~ data ~ ";
	mixins_event.down(); }";
	return str;
}

class PiPeline
{
	@disable this();

	this(Channel chan){
		_channel = chan;
		switch(_channel.type){
			case CHANNEL_TYPE.TCP_Listener:
			{
				TCPListener listen = cast(TCPListener) _channel;
				listen.setConnectHandler(&onNewTcp);
			}
				break;
			case CHANNEL_TYPE.TCP_Socket:
			{
				auto sock = cast(TCPSocket) _channel;
				sock.colsedHandler(&onClose);
				sock.writeHandler(&onWrite);
				sock.readHandler(&onRead);
				sock.statusHandler(&onStatus);
			}
				break;
				version(SSL) {
					case CHANNEL_TYPE.SSL_Listener:
					{
						auto listen = cast(SSLlistener) _channel;
						listen.setConnectHandler(&onNewSSL);
					}
					break;
					case CHANNEL_TYPE.SSL_Socket:
					{
						auto sock = cast(SSLSocket) _channel;
						sock.colsedHandler(&onClose);
						sock.writeHandler(&onWrite);
						sock.readHandler(&onRead);
						sock.statusHandler(&onStatus);
					}
					break;
				}
			case CHANNEL_TYPE.Timer :
			{
				auto timer = cast(Timer) _channel;
				timer.setCallBack(&onTimeOut);
			}
				break;
			default:
				break;

		}
	}

	~this(){
		//destroy(_out);
		_out = null;
	//	destroy(_in);
		_in = null;
		_channel = null;
	}

	void pushHandle(Handler hand){
		_in ~= hand;
		_out ~= hand;
	}

	void pushInhandle(InHander handle){
		_in ~= handle;
	}

	void pushOutHandle(OutHander handle){
		_out ~= handle;
	}

	@property const(Channel) channel() const{
		return _channel;
	}

	@property Channel channel(){
		return _channel;
	}

	bool isVaild() const {
		return (_out.length > 0) || (_in.length > 0);
	}

package:
	void upEvent(InEvent event){
		trace("up Event level:",event.level);
		if (event.level >= _in.length){
			return;
		}
		_in[event.level].inEvent(event);
	}
	void downEvent(OutEvent event) {
		trace("down Event level:",event.level);
		if(event.level >= _out.length || event.level  < 0)  return;
		if(event.level == 0){
			if(event.type == OUTEVENT_TCP_WRITE){
				scope auto ev = cast(OutEventTCPWrite)event;
				bool suess = false;
				switch (channel.type){
					case CHANNEL_TYPE.TCP_Socket:
					{
						auto tcp = cast(TCPSocket) channel;
						trace("write tcp:",cast(string)ev.data);
						suess = tcp.write(ev.data);
					}
						break;
					version(SSL){
						case CHANNEL_TYPE.SSL_Socket:
						{
							auto ssl = cast(SSLSocket) channel;
							trace("write ssl:",cast(string)ev.data);
							suess = ssl.write(ev.data);
						}
							break;
					}
					default:
						break;
				}
				if(!suess){
					trace("write data erro:",ev.data.length);
					scope auto inEv = new INEventWrite(this);
					inEv.data = ev.data;
					inEv.wsize = 0;
					inEv.up();
				}
			} else if (event.type == OUTEVENT_UDP_WRITE && channel.type == CHANNEL_TYPE.UDP_Socket) {

			} else if (event.type == OUTEVENT_CLOSE) {
				switch (channel.type){
					case CHANNEL_TYPE.TCP_Socket:
					{
						auto tcp = cast(TCPSocket) channel;
						tcp.close();
					}
						break;
					case CHANNEL_TYPE.Timer:
					{
						auto tm = cast(Timer) channel;
						tm.kill();
					}
						break;
					case CHANNEL_TYPE.TCP_Listener:
					{
						auto tl = cast(TCPListener) channel;
						tl.kill();
					}
						break;
					case CHANNEL_TYPE.UDP_Socket:
					{
					}
						break;
						version(SSL){
							case CHANNEL_TYPE.SSL_Socket:
							{
								auto tcp = cast(SSLSocket) channel;
								tcp.close();
							}
							break;
							case CHANNEL_TYPE.SSL_Listener:
							{
								auto tl = cast(SSLlistener) channel;
								tl.kill();
							}
							break;
						}

					default:
						break;
				}
			}
			return ;
		}
		_out[event.level -1 ].outEvent(event);
	}

	
	void onRead(ubyte[] data){
		trace("tcp on read:", cast(string)data);
		scope auto ev = new INEventTCPRead(this);
		ev.data = data;
		ev.up();
	}
	void onClose(ubyte[][] buffers)
	{
		scope auto ev = new InEventTCPClose(this);
		ev.buffers = buffers;
		ev.up();
		version(TCP_POOL) {
			if(!TCPPool.full) {
				TCPPool.enQueue(cast(TCPSocket)_channel);
			}
		}
	}
	void onWrite(ubyte[] data,uint wsize)
	{
		scope auto ev = new INEventWrite(this);
		ev.data = data;
		ev.wsize = wsize;
		ev.up();
	}
	void onStatus(SOCKET_STATUS sfrom,SOCKET_STATUS sto)
	{
		scope auto ev = new INEventSocketStatusChanged(this);
		ev.status_from = sfrom;
		ev.status_to = sto;
		ev.up();
	}
	void onTimeOut()
	{
		scope auto ev = new INEventTimeOut(this);
		ev.up();
	}
	void onNewTcp(TCPSocket socket)
	{
		scope auto ev = new INEventNewConnect(this);
		ev.sock = socket;
		ev.up();
	}
	version(SSL) {
		void onNewSSL(SSLSocket socket)
		{
			scope auto ev = new INEventNewConnect(this);
			ev.sock = socket;
			ev.up();
		}
	}

	uint getOutLevel(OutHandle ou) const {
		uint size = cast(uint)_out.length;
		if(ou is null) return size;
		while (size > 0) {
			if(_out[size - 1] == ou) return size;
			--size;
		}
		return 0;
	}
private:
	OutHandle[] _out;
	InHandle[] _in;
	Channel _channel;
};

scope abstract class Event
{
	@disable this();
	@property uint type() {return _type;}
	@property const(PiPeline) pipeline() const {return _pipeline;}
package:
	this(const PiPeline pip,uint ty){_type = ty;_pipeline = pip; }
private:
	uint _type;
	const PiPeline _pipeline;
};

abstract class InEvent: Event
{
	this(const InEvent ev,uint ty)
	{super(ev.pipeline,ty);level = ev.level;}

	final void up(){
		++level;
		auto pip = cast(PiPeline) this.pipeline;
		pip.upEvent(this);
	}
package:
	this(const PiPeline pip,uint ty){super(pip,ty);}

private:
	int level = -1;
};

abstract class OutEvent: Event
{
	this(const OutEvent ev,uint ty)
	{super(ev.pipeline,ty);level = ev.level;}
	this(const PiPeline pip,uint ty)
	{super(pip,ty);level = pip.getOutLevel(null);}
	this(const PiPeline pip,uint ty,OutHandle hand){
		super(pip,ty);
		level = pip.getOutLevel(hand);
	}

	final void down(){
		--level;
		auto pip = cast(PiPeline) this.pipeline;
		pip.downEvent(this);
	}
private:
	int level = -1;
};

enum {
	INEVENT_TCP_CLOSED = 0,
	INEVENT_TCP_READ = 1,
	INEVENT_UDP_READ = 2,
	INEVENT_WRITE = 3,
	INEVENT_STATUS_CHANGED = 4,
	INEVENT_TIMEROUT = 5,
	INEVENT_NEWCONNECT = 6,
	//INEVENT_TCP_CLOSED = 7,
	OUTEVENT_TCP_WRITE = 8,
	OUTEVENT_UDP_WRITE = 9,
	OUTEVENT_CLOSE = 10
	//	INEVENT_WRITE_EORR = 11,
};

/*final class INEventClosed : InEvent
 {
 package:
 this(const PiPeline pip){super(pip,INEVENT_CLOSED);}
 }*/

final class INEventTCPRead : InEvent
{
	ubyte[] data;
package:
	this(const PiPeline pip){super(pip,INEVENT_TCP_READ);}
}

//final class INEventUDPRead : InEvent
//{
//}

final class INEventWrite : InEvent
{
	ubyte[] data;
	uint wsize;
package:
	this(const PiPeline pip){super(pip,INEVENT_WRITE);}
}

/*
 final class INEventWriteErro : InEvent
 {
 ubyte[] data;
 package:
 this(const PiPeline pip){super(pip,INEVENT_WRITE_EORR);}
 }*/


final class INEventSocketStatusChanged : InEvent
{
	SOCKET_STATUS status_from;
	SOCKET_STATUS status_to;
package:
	this(const PiPeline pip){super(pip,INEVENT_STATUS_CHANGED);}
}

final class INEventTimeOut : InEvent
{
package:
	this(const PiPeline pip){super(pip,INEVENT_TIMEROUT);}
}

final class INEventNewConnect : InEvent
{
	Channel sock;
package:
	this(const PiPeline pip){super(pip,INEVENT_NEWCONNECT);}
}

final class InEventTCPClose : InEvent
{
	ubyte[][] buffers = null;
package:
	this(const PiPeline pip){super(pip,INEVENT_TCP_CLOSED);}
}


final class OutEventTCPWrite : OutEvent
{
	this(const OutEvent ev) {super(ev,OUTEVENT_TCP_WRITE);}

	this(const PiPeline pip){super(pip,OUTEVENT_TCP_WRITE);}

	this(const PiPeline pip,OutHandle hand){
		super(pip,OUTEVENT_TCP_WRITE,hand);
	}
	ubyte[] data;
}

final class OutEventUDPWrite : OutEvent
{
	this(const OutEvent ev){super(ev,OUTEVENT_UDP_WRITE);}

	this(const PiPeline pip){super(pip,OUTEVENT_UDP_WRITE);}

	this(const PiPeline pip,OutHandle hand){
		super(pip,OUTEVENT_UDP_WRITE,hand);
	}
	ubyte[] data;
	Address addr;
}

final class OutEventClose : OutEvent
{
	this(const OutEvent ev){super(ev,OUTEVENT_CLOSE);}

	this(const PiPeline pip){super(pip,OUTEVENT_CLOSE);}

	this(const PiPeline pip,OutHandle hand){
		super(pip,OUTEVENT_CLOSE,hand);
	}
}

private const uint eventStartType = 100;
private __gshared uint eventTypeNum ;
private __gshared Mutex m_mutex;

shared static this()
{
	m_mutex = new Mutex();
}

uint getEventType()
{
	uint type;
	synchronized (m_mutex) {
		++eventTypeNum;
		type = eventTypeNum + eventStartType;
	}
	return type;
}


unittest {//test scope calss数据传递方式，值传还是址传
	void  fun1() 
	{
		scope auto c2 = new MyClass;
		c2.tid = 1;
		writeln("the class tid = ", c2.tid); //输出1
		fun2(c2);
		writeln("the fun2 after class tid = ", c2.tid); //输出5,是址传
	}
	
	void fun2(MyClass c2)
	{
		c2.tid = 5;
	}

}