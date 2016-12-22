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

version (Windows)  : 
pragma(lib, "Ws2_32");

import core.time;
import core.memory;

public import core.sys.windows.windows;
public import core.sys.windows.winsock2;
public import core.sys.windows.mswsock;

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
        _iocp = CreateIoCompletionPort(INVALID_HANDLE_VALUE, null, 0, 1);
        if (!_iocp)
        {
            errnoEnforce("CreateIoCompletionPort failed");
        }
        _event.operationType = IOCP_OP_TYPE.event;
        _event.event = null;
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
        if (event.type == AsynType.ACCEPT || event.type == AsynType.TCP || event.type
                == AsynType.UDP)
        {
            try
            {
                auto v = CreateIoCompletionPort(cast(HANDLE) event.fd, _iocp,
                    cast(ULONG_PTR) event, 1);
                event.isActive(true);
                if (!v)
                    return false;
            }
			catch(Exception e)
			{
				collectException(error(e.toString));
			}
        }
        return true;
    }

    bool modEvent(AsyncEvent * event) nothrow
    {
        return true;
    }

    bool delEvent(AsyncEvent * event) nothrow
    {
        event.isActive(false);
        return true;
    }

    void wait(int timeout)
    {
        OVERLAPPED * overlapped;
        ULONG_PTR key = 0;
        DWORD bytes = 0;
        int va = GetQueuedCompletionStatus(_iocp,  & bytes,  & key,  & overlapped,
            timeout);
		if (overlapped is null) // timeout
			return;
        if (va == 0)
        {
            auto erro = GetLastError();
            if (erro == WAIT_TIMEOUT)
                return;
			//error("GetQueuedCompletionStatus erro! : ", erro);
            auto ev = cast(IOCP_DATA * ) overlapped;
            if (ev && ev.event)
            {
                if (ev.event.obj)
                    ev.event.obj.onClose();
            }
            return;

        }
        auto ev = cast(IOCP_DATA * ) overlapped;
        final switch (ev.operationType)
        {
        case IOCP_OP_TYPE.accept : ev.event.obj.onRead();
            break;
        case IOCP_OP_TYPE.connect : ev.event.writeLen = 0;
            ev.event.obj.onWrite();
            break;
        case IOCP_OP_TYPE.read : 
			if (bytes > 0)
            {
                ev.event.readLen = bytes;
                ev.event.obj.onRead();
            }
            else
            {
                ev.event.obj.onClose();
            }
            break;
        case IOCP_OP_TYPE.write : if (bytes > 0)
            {
                ev.event.writeLen = bytes;
                ev.event.obj.onWrite();
            }
            else
            {
                ev.event.obj.onClose();
            }
            break;
        case IOCP_OP_TYPE.event : break;
        }

        return;
    }

    void weakUp() nothrow
    {
        try
        {
            PostQueuedCompletionStatus(_iocp, 0, 0, cast(LPOVERLAPPED)( & _event));
        }
		catch(Exception e)
		{
			collectException(error(e.toString));
		}
    }
    private : HANDLE _iocp;
    IOCP_DATA _event;
}

struct IOCP_DATA
{
    OVERLAPPED ol;
    IOCP_OP_TYPE operationType;
    AsyncEvent * event = null;
}

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
    int iResult = WSAStartup(MAKEWORD(2, 2),  & wsaData);
    if (iResult != NO_ERROR)
    {
        errnoEnforce("iocp init error!");
    }

    SOCKET ListenSocket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    scope (exit)
        closesocket(ListenSocket);
    GUID guid;
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

private 
{
bool GetFunctionPointer(FuncPointer)(SOCKET sock, ref FuncPointer pfn, ref GUID guid)
{
    DWORD dwBytesReturned = 0;
    if (WSAIoctl(sock, SIO_GET_EXTENSION_FUNCTION_POINTER,  & guid, guid.sizeof,
             & pfn, pfn.sizeof,  & dwBytesReturned, null, null) == SOCKET_ERROR)
    {
        error("Get function failed with error:", GetLastError());
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
}

alias OVERLAPPED WSAOVERLAPPED;
alias OVERLAPPED* LPWSAOVERLAPPED;

struct WSABUF {
        uint  len;
        char* buf;
}

alias WSABUF* LPWSABUF;

enum : DWORD {
    IOCPARAM_MASK = 0x7f,
    IOC_VOID      = 0x20000000,
    IOC_OUT       = 0x40000000,
    IOC_IN        = 0x80000000,
    IOC_INOUT     = IOC_IN|IOC_OUT
}


enum IOC_UNIX = 0x00000000;
enum IOC_WS2 = 0x08000000;
enum IOC_PROTOCOL = 0x10000000;
enum IOC_VENDOR = 0x18000000;

template _WSAIO(int x, int y) { enum _WSAIO = IOC_VOID | x | y; }
template _WSAIOR(int x, int y) { enum _WSAIOR = IOC_OUT | x | y; }
template _WSAIOW(int x, int y) { enum _WSAIOW = IOC_IN | x | y; }
template _WSAIORW(int x, int y) { enum _WSAIORW = IOC_INOUT | x | y; }

enum SIO_ASSOCIATE_HANDLE               = _WSAIOW!(IOC_WS2,1);
enum SIO_ENABLE_CIRCULAR_QUEUEING       = _WSAIO!(IOC_WS2,2);
enum SIO_FIND_ROUTE                     = _WSAIOR!(IOC_WS2,3);
enum SIO_FLUSH                          = _WSAIO!(IOC_WS2,4);
enum SIO_GET_BROADCAST_ADDRESS          = _WSAIOR!(IOC_WS2,5);
enum SIO_GET_EXTENSION_FUNCTION_POINTER = _WSAIORW!(IOC_WS2,6);
enum SIO_GET_QOS                        = _WSAIORW!(IOC_WS2,7);
enum SIO_GET_GROUP_QOS                  = _WSAIORW!(IOC_WS2,8);
enum SIO_MULTIPOINT_LOOPBACK            = _WSAIOW!(IOC_WS2,9);
enum SIO_MULTICAST_SCOPE                = _WSAIOW!(IOC_WS2,10);
enum SIO_SET_QOS                        = _WSAIOW!(IOC_WS2,11);
enum SIO_SET_GROUP_QOS                  = _WSAIOW!(IOC_WS2,12);
enum SIO_TRANSLATE_HANDLE               = _WSAIORW!(IOC_WS2,13);
enum SIO_ROUTING_INTERFACE_QUERY        = _WSAIORW!(IOC_WS2,20);
enum SIO_ROUTING_INTERFACE_CHANGE       = _WSAIOW!(IOC_WS2,21);
enum SIO_ADDRESS_LIST_QUERY             = _WSAIOR!(IOC_WS2,22);
enum SIO_ADDRESS_LIST_CHANGE            = _WSAIO!(IOC_WS2,23);
enum SIO_QUERY_TARGET_PNP_HANDLE        = _WSAIOR!(IOC_WS2,24);
enum SIO_NSP_NOTIFY_CHANGE              = _WSAIOW!(IOC_WS2,25);


extern(Windows):
nothrow:

int WSARecv(SOCKET, LPWSABUF, DWORD, LPDWORD, LPDWORD, LPWSAOVERLAPPED, LPWSAOVERLAPPED_COMPLETION_ROUTINE);
int WSARecvDisconnect(SOCKET, LPWSABUF);
int WSARecvFrom(SOCKET, LPWSABUF, DWORD, LPDWORD, LPDWORD, SOCKADDR*, LPINT, LPWSAOVERLAPPED, LPWSAOVERLAPPED_COMPLETION_ROUTINE);

int WSASend(SOCKET, LPWSABUF, DWORD, LPDWORD, DWORD, LPWSAOVERLAPPED, LPWSAOVERLAPPED_COMPLETION_ROUTINE);
int WSASendDisconnect(SOCKET, LPWSABUF);
int WSASendTo(SOCKET, LPWSABUF, DWORD, LPDWORD, DWORD, const(SOCKADDR)*, int, LPWSAOVERLAPPED, LPWSAOVERLAPPED_COMPLETION_ROUTINE);