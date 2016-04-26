/* Copyright collied.org 
*/

module collie.channel.address;

import collie.channel.define;
import collie.channel.define;

public import std.conv : to;
import std.bitmanip;
import std.string;
import Socked = std.socket;

/** 网络地址类的封装。
    @author : Putao‘s Collie Team
    @date : 2016.1
*/
struct Address {
	/** 构造函数
	@param : port = 端口，地址的端口
	@param : isV6 = IP地址是不是IP v6
	*/
	this (ushort port,bool isV6 = false) {
		if(isV6) {
			this("::",port,isV6);
		} else { 
			this("0.0.0.0",port,isV6);
		}
	}

	/** 构造函数 
	@param : ip   = IP地址的身体日那个表达
	@param : port = 端口，地址的端口
	@param : isV6 = IP地址是不是IP v6
	*/
	this (string ip, ushort port,bool isV6 = false) {
		if(ip.length == 0) {
			error("Invalid address ip or port");
			return;
		}
	//	ip ~= "\0";
		auto tip = toStringz(ip);
		if(isV6)  {
			if(inet_pton(AF_INET6,tip,&addr_ip6.sin6_addr) > 0) {//inet_addr(_ip.ptr);
				addr_ip6.sin6_family = AF_INET6;
			} else {
				error("inet_pton ip6 erro: the ip = ",ip);
			}
			addr_ip6.sin6_port = htons(port);
		} else {
			if(inet_pton(AF_INET,tip,&addr_ip4.sin_addr)) { //inet_addr(_ip.ptr); 
				addr_ip4.sin_family = AF_INET;
			} else {
				error("inet_pton ip4 erro: the ip = ",ip);
			}
			addr_ip4.sin_port = htons(port);
		}
	}

	/** 构造函数 
	@param : address   = IP v4地址的系统结构体
	*/
	this (sockaddr_in address) {
		addr_ip4 = address;
	}
	/** 构造函数 
            @param : address   = IP v6地址的系统结构体
	*/
	this (sockaddr_in6 address) {
		addr_ip6 = address;
	}

	/** 构造函数 
            @param : isV6 = IP地址是不是IP v6
	*/
	this(bool isV6) {
		if(isV6) {
			addr_ip6.sin6_family = AF_INET6;
		} else {
			addr_ip4.sin_family = AF_INET;
		}
	}
	/** 返回当前地址是否为IP V6地址 */
	bool isIpV6() pure nothrow @nogc { return this.family == AF_INET6; }
	/** 返回当前地址是否是有效和端口是否完整
            @return :(true) 地址和端口都正确，(false) 地址和端口有一个不正确。
	*/
	bool isVaild() pure nothrow @nogc { return (this.family == AF_INET6 || this.family == AF_INET) && getPort > 0; }
	/** 返回当前地址是否是有效
            @return : (true) 地址正确，(false) 地址不正确。
	*/
	bool isIpVaild() pure nothrow @nogc { return (this.family == AF_INET6 || this.family == AF_INET) ; }

	/** 获取当前的IP地址
            @return : 返回当前地址的字符串表示
	*/
	string getIp() {
		import std.array : appender;
		import std.string : format;
		import std.format : formattedWrite;

		switch (this.family) {
			default: assert(false, "toAddressString() called for invalid address family.");
			case AF_INET:
				ubyte[4] ip = (cast(ubyte*)&addr_ip4.sin_addr.s_addr)[0 .. 4];
				return format("%d.%d.%d.%d", ip[0], ip[1], ip[2], ip[3]);
			case AF_INET6:
				ubyte[16] ip = addr_ip6.sin6_addr.s6_addr;
				auto ret = appender!string();
				ret.reserve(40);
				foreach (i; 0 .. 8) {
					if (i > 0) ret.put(':');
					ret.formattedWrite("%x", bigEndianToNative!ushort(cast(ubyte[2])ip[i*2 .. i*2+2].ptr[0 .. 2]));
				}
				return ret.data;
		}
	}

	/** 获取当前地址的协议族*/
	@safe @property ushort family() const pure nothrow @nogc{ return addr.sa_family; }
	
	/** 获取当前地址的端口
	*/
	@safe ushort getPort() pure nothrow @nogc {
		switch (this.family) {
			default: assert(false, "port() called for invalid address family.");
			case AF_INET: return ntohs(addr_ip4.sin_port);
			case AF_INET6: return ntohs(addr_ip6.sin6_port);
		}
	}

	/** 获取系统地址结构体的指针 */
	@safe  @property const(sockaddr) * sockAddr() const pure nothrow @nogc {
		return &addr;
	}
	/** 获取系统地址结构体的指针 */
	@safe  @property sockaddr * sockAddr() pure nothrow @nogc {
		return &addr;
	}

	/** 获取系统地址结构体所占的字节的大小 */
	@safe @property uint sockAddrLen() const pure nothrow @nogc {
		switch (this.family) {
			default: assert(false, "sockAddrLen() called for invalid address family.");
			case AF_INET: return addr_ip4.sizeof;
			case AF_INET6: return addr_ip6.sizeof;
		}
	}

	Socked.Address toStdAddress() {
		return new ColliedAddress(this);
	}
package :
        /** 设置当前地址的协议族 */
	@property void family(ushort val) pure nothrow @nogc { addr.sa_family = cast(ubyte)val; }
private :
	union {
		sockaddr addr;
		sockaddr_in addr_ip4;
		sockaddr_in6 addr_ip6;
	}; 
}


class ColliedAddress : Socked.Address {
	this(ref Address addr){ _addr = addr; }

	override @property sockaddr* name() pure nothrow @nogc {
		return _addr.sockAddr();
	}

	override @property const(sockaddr)* name() const pure nothrow @nogc {
		return _addr.sockAddr();
	}

	override @property socklen_t nameLen() const pure nothrow @nogc {
		return cast(socklen_t)_addr.sockAddrLen();
	}

	@property Address address(){ return _addr; }
private:
	Address _addr;
}
