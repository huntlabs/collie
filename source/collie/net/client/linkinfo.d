/*
 * Collie - An asynchronous event-driven network framework using Dlang development
 *
 * Copyright (C) 2015-2017  Shanghai Putao Technology Co., Ltd 
 *
 * Developer: putao's Dlang team
 *
 * Licensed under the Apache-2.0 License.
 *
 */
module collie.net.client.linklogInfo;

import std.socket;
import kiss.net.TcpStream;

struct TLinklogInfo(TCallBack) if(is(TCallBack == delegate))
{
	TcpStream client;
	Address addr;
	uint tryCount = 0;
	TCallBack cback;

private:
	TLinklogInfo!(TCallBack) * prev;
	TLinklogInfo!(TCallBack) * next;
}

struct TLinkManger(TCallBack) if(is(TCallBack == delegate))
{
	alias LinklogInfo = TLinklogInfo!TCallBack;

	void addlogInfo(LinklogInfo * logInfo)
	{
		if(logInfo){
			logInfo.next = _logInfo.next;
			if(logInfo.next){
				logInfo.next.prev = logInfo;
			}
			logInfo.prev = &_logInfo;
			_logInfo.next = logInfo;
		}
	}

	void rmlogInfo(LinklogInfo * logInfo)
	{
		logInfo.prev.next = logInfo.next;
		if (logInfo.next)
			logInfo.next.prev = logInfo.prev;
		logInfo.next = null;
		logInfo.prev = null;
	}

private:
	LinklogInfo _logInfo;
}