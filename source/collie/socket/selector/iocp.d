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
module collie.socket.selector.iocp;

version(Windows):

public import core.sys.windows.windows;

final class IOCP
{
	this()
	{
		_iocp = CreateIoCompletionPort( INVALID_HANDLE_VALUE, null, 0, 1 );
		if (!_iocp)
		{
			errnoEnforce("epoll_create1 failed");
		}
		
		_event = new EventChannel();
		addEvent(_event._event);
	}

	~this()
	{
		.close(_efd);
		_event.destroy;
	}
	
	/** 添加一个Channel对象到事件队列中。
	 @param   socket = 添加到时间队列中的Channel对象，根据其type自动选择需要注册的事件。
	 @return true 添加成功, false 添加失败，并把错误记录到日志中.
	 */
	bool addEvent(AsyncEvent * event) nothrow
	{

		return true;
	}
	
	bool modEvent(AsyncEvent * event) nothrow
	{
		return true;
	}

	bool delEvent(AsyncEvent * event) nothrow
	{
		return true;
	}

	void wait(int timeout)
	{

		return;
	}
	
	void weakUp() nothrow
	{
		_event.doWrite();
	}
private:
	HANDLE        _iocp;
	EventChannel _event;
}
