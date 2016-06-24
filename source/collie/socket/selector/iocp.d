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

import collie.socket.common;
version(Windows):
pragma(lib, "Ws2_32");

import core.time;
import core.memory;

public import  windows.windows;
public import  windows.winsock2;
public import  windows.mswsock;

import std.conv;
import std.exception;
import std.experimental.logger;

enum IOCP_OP_TYPE
{
	accept,
	connect,
	read,
	write,
	event
}

final class IOCPLoop
{
	this()
	{
		_iocp = CreateIoCompletionPort( INVALID_HANDLE_VALUE, null, 0, 1 );
		if (!_iocp)
		{
			errnoEnforce("CreateIoCompletionPort failed");
		}
		_event.operationType = IOCP_OP_TYPE.event;
	}

	~this()
	{
	}
	
	/** 添加一个Channel对象到事件队列中。
	 @param   socket = 添加到时间队列中的Channel对象，根据其type自动选择需要注册的事件。
	 @return true 添加成功, false 添加失败，并把错误记录到日志中.
	 */
	bool addEvent(AsyncEvent * event) nothrow
	{
		if(event.type == AsynType.ACCEPT || event.type == AsynType.TCP ||  event.type == AsynType.UDP)
		{
			try{
			auto v = CreateIoCompletionPort(cast(HANDLE)event.fd,_iocp,cast(ULONG_PTR)event,1);
			if(!v) return false;
			}catch{}
		}
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
		OVERLAPPED * overlapped ;
		ULONG_PTR key=0;
		DWORD bytes=0;
		int va = GetQueuedCompletionStatus(_iocp,&bytes, &key,&overlapped, timeout);
		if(va == 0)
		{
                    if(overlapped is null) // timeout
			return;
                    auto erro = GetLastError();
                    if(erro == WAIT_TIMEOUT) return;
                    auto ev = cast(IOCP_DATA *)overlapped;
                    if(ev.event)
                        ev.event.obj.onClose();
                    return;
                    
		}
		if(overlapped is null) return;
		auto ev = cast(IOCP_DATA *)overlapped;
		final switch (ev.operationType)
		{
                    case IOCP_OP_TYPE.accept:
                        ev.event.obj.onRead();
                        break;
                    case IOCP_OP_TYPE.connect:
                        ev.event.writeLen = 0;
                        ev.event.obj.onWrite();
                        break;
                    case IOCP_OP_TYPE.read:
                        if(bytes > 0)
                        {
                            ev.event.readLen = bytes;
                            ev.event.obj.onRead();
                        }
                        else
                        {
                            ev.event.obj.onClose();
                        }
                        break;
                    case IOCP_OP_TYPE.write:
                        if(bytes > 0)
                        {
                            ev.event.writeLen = bytes;
                            ev.event.obj.onWrite();
                        }
                        else
                        {
                            ev.event.obj.onClose();
                        }
                        break;
                    case IOCP_OP_TYPE.event:
                        break;
		}
	
		return;
	}
	
	void weakUp() nothrow
	{
		try{
            PostQueuedCompletionStatus(_iocp,0,0,cast(LPOVERLAPPED)(&_event));
		}catch{}
	}
private:
    HANDLE        _iocp;
    IOCP_DATA   _event;
}

struct IOCP_DATA
{
        OVERLAPPED ol;
        IOCP_OP_TYPE operationType;
        AsyncEvent * event = null;
}
/*
struct __WSABUF
{ 
    ulong len;
    char  *buf;
} 

alias WSABUF = __WSABUF;
alias LPWSABUF = __WSABUF *;

int WSASend(SOCKET,LPWSABUF,DWORD,LPDWORD,DWORD,OVERLAPPED *,LPWSAOVERLAPPED_COMPLETION_ROUTINE);
int WSARecv(SOCKET,LPWSABUF ,DWORD ,LPDWORD ,LPINT ,OVERLAPPED * ,LPWSAOVERLAPPED_COMPLETION_ROUTINE );

}*/
__gshared static LPFN_ACCEPTEX AcceptEx;
__gshared static LPFN_CONNECTEX ConnectEx;
/*__gshared LPFN_DISCONNECTEX DisconnectEx;
__gshared LPFN_GETACCEPTEXSOCKADDRS GetAcceptexSockAddrs;
__gshared LPFN_TRANSMITFILE TransmitFile;
__gshared LPFN_TRANSMITPACKETS TransmitPackets;
__gshared LPFN_WSARECVMSG WSARecvMsg;
__gshared LPFN_WSASENDMSG WSASendMsg;*/

shared static this()
{
    WSADATA wsaData;
    int iResult = WSAStartup( MAKEWORD(2,2), &wsaData );
    if(iResult != NO_ERROR )
    {
        errnoEnforce("iocp init error!");
    }
    SOCKET ListenSocket = WSASocket(AF_INET,SOCK_STREAM,IPPROTO_TCP, null,0, WSA_FLAG_OVERLAPPED);//socket(AF_INET, SOCK_STREAM, IPPROTO_TCP );
	GUID guid ;
     mixin(GET_FUNC_POINTER("WSAID_ACCEPTEX", "AcceptEx"));
     mixin(GET_FUNC_POINTER("WSAID_CONNECTEX", "ConnectEx"));
    /* mixin(GET_FUNC_POINTER("WSAID_DISCONNECTEX", "DisconnectEx"));
     mixin(GET_FUNC_POINTER("WSAID_GETACCEPTEXSOCKADDRS", "GetAcceptexSockAddrs"));
     mixin(GET_FUNC_POINTER("WSAID_TRANSMITFILE", "TransmitFile"));
     mixin(GET_FUNC_POINTER("WSAID_TRANSMITPACKETS", "TransmitPackets"));
     mixin(GET_FUNC_POINTER("WSAID_WSARECVMSG", "WSARecvMsg"));*/
}

shared static ~this()
{
    WSACleanup();
}

private:

bool GetFunctionPointer(FuncPointer)( SOCKET sock, ref FuncPointer pfn, ref GUID guid )
{
        DWORD dwBytesReturned = 0;
        if( WSAIoctl( sock, SIO_GET_EXTENSION_FUNCTION_POINTER, &guid, guid.sizeof, 
                &pfn, pfn.sizeof,
                &dwBytesReturned, null, null ) == SOCKET_ERROR  ){
                        error("Get function failed with error:", GetLastError() );
                        return false;
        }

        return true;
}

string GET_FUNC_POINTER(string GuidValue, string pft)
{
    string str = " guid = " ~ GuidValue ~ ";";
    str ~= "if( !GetFunctionPointer( ListenSocket, " ~ pft ~ ", guid ) ) { errnoEnforce(\"iocp get function error!\"); } ";
    return str;
}
