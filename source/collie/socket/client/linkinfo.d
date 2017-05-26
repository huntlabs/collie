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
module collie.socket.client.linkinfo;

import std.socket;
import collie.socket.tcpclient;

struct TLinkInfo(TCallBack) if(is(TCallBack == delegate))
{
	TCPClient client;
	Address addr;
	uint tryCount = 0;
	TCallBack cback;

private:
	TLinkInfo!(TCallBack) * prev;
	TLinkInfo!(TCallBack) * next;
}

struct TLinkManger(TCallBack) if(is(TCallBack == delegate))
{
	alias LinkInfo = TLinkInfo!TCallBack;

	void addInfo(LinkInfo * info)
	{
		if(info){
			info.next = _info.next;
			if(info.next){
				info.next.prev = info;
			}
			info.prev = &_info;
			_info.next = info;
		}
	}

	void rmInfo(LinkInfo * info)
	{
		info.prev.next = info.next;
		if (info.next)
			info.next.prev = info.prev;
		info.next = null;
		info.prev = null;
	}

private:
	LinkInfo _info;
}