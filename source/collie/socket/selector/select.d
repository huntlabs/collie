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

module collie.socket.selector.select;

import core.time;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.format;
import std.socket;
import std.experimental.logger;

import collie.socket.common;

static if(IOMode == IO_MODE.select)
{
	//TODO: Need Test
	class SelectLoop
	{
		this()
		{
			_event = new EventChannel();
			addEvent(_event._event);
			_readSet = new SocketSet();
			_writeSet = new SocketSet();
			_errorSet = new SocketSet();
		}
		
		~this()
		{
			_event.destroy;
		}
		
		bool addEvent(AsyncEvent* event) nothrow
		{
			try
			{
				_socketList[event.fd] = event;
			} catch(Exception e) {
				collectException(warning(e.toString));
				return false;
			}
			return true;
		}

		bool modEvent(AsyncEvent* event) nothrow
		{
			return true;
		}

		bool delEvent(AsyncEvent* event) nothrow
		{
			try{
				_socketList.remove(event.fd);
			} catch(Exception e) {
				collectException(warning(e.toString));
				return false;
			}
			return true;
		}

		void weakUp() nothrow
		{
			_event.doWrite();
		}

		void wait(int timeout)
		{
			_readSet.reset();
			_writeSet.reset();
			_errorSet.reset();
			foreach(key,value; _socketList)
			{
				_errorSet.add(key);
				if(value.enRead)
					_readSet.add(key);
				if(value.enWrite)
					_writeSet.add(key);
			}
			int n = Socket.select(_readSet,_writeSet,_errorSet, dur!("msecs")(timeout));
			if(n <= 0) return;
			foreach(key,value; _socketList)
			{
				if(_errorSet.isSet(key) > 0)
				{
					value.obj.onClose();
					continue;
				}
				if(_writeSet.isSet(key) > 0)
					value.obj.onWrite();
				if(_readSet.isSet(key) > 0)
					value.obj.onRead();
			}
		}

	private:
		AsyncEvent*[socket_t] _socketList;
		
		SocketSet _writeSet;
		SocketSet _readSet;
		SocketSet _errorSet;
		
		EventChannel _event;
	}

	static this()
	{
		import core.sys.posix.signal;

		signal(SIGPIPE, SIG_IGN);
	}

	private final class EventChannel : EventCallInterface
	{
		this()
		{
			_pair = socketPair();
			_pair[0].blocking = false;
			_pair[1].blocking = false;
			_event = AsyncEvent.create(AsynType.EVENT, this, _pair[1].handle(), true, false,
				false);
		}

		~this()
		{
			AsyncEvent.free(_event);
		}

		void doWrite() nothrow
		{
			try
			{
				_pair[0].send("wekup");
			}
			catch(Exception e)
			{
				collectException(warning(e.toString));
			}
		}

		override void onRead() nothrow
		{
			ubyte[128] data;
			while (true)
			{
				try
				{
					if (_pair[1].receive(data) <= 0)
						return;
				}
				catch(Exception e)
				{
					collectException(warning(e.toString));
				}
			}
		}

		override void onWrite() nothrow
		{
		}

		override void onClose() nothrow
		{
		}

		Socket[2] _pair;
		AsyncEvent* _event;
	}

}