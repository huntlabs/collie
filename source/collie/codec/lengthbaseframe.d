module collie.codec.lengthbaseframe;

import std.bitmanip;
import std.conv;
import kiss.logger;
import kiss.event;

import collie.channel;
import collie.codec.exception;
import kiss.container.ByteBuffer;

/// The Pack format
/// header: ubytes 4 "00 00 00 00" -> uint 
/// Compress Type: ubyte one "00"
/// the data is a data.

class MsgLengthTooBig : CollieCodecException
{
	pure nothrow @nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, file, line);
	}
}

class LengthBasedFrame(bool littleEndian = false) : Handler!(const(ubyte[]),ubyte[],ubyte[],StreamWriteBuffer)
{
	this(uint max, ubyte compressType = 0x00)
	{
		_max = max;
		_compressType = compressType;
		//    clear();
	}

	final override void read(Context ctx, const(ubyte[]) msg)
	{

		void doFireRead()
		{
			if(_data.length > 0)
				_data = unCompress(_readComType,_data);
			ctx.fireRead(_data);
			_data = null;
			_pos = ReadPOS.Length_Begin;
		}

		size_t len = msg.length;
		for(size_t i = 0; i < len; ++i)
		{
			const ubyte ch = msg[i];
			final switch(_pos)
			{
				case ReadPOS.Length_Begin:
					_lenByte[0] = ch;
					_pos = ReadPOS.Length_1;
					break;
				case ReadPOS.Length_1:
					_lenByte[1] = ch;
					_pos = ReadPOS.Length_2;
					break;
				case ReadPOS.Length_2:
					_lenByte[2] = ch;
					_pos = ReadPOS.Length_End;
					break;
				case ReadPOS.Length_End:
					_lenByte[3] = ch;
					_pos = ReadPOS.Compress_Type;
					break;
				case ReadPOS.Compress_Type:
					_readComType = ch;
					_pos = ReadPOS.Body;
					_readLen = 0;
					_msgLen = endianToNative!(littleEndian,uint)(_lenByte);
					if(_msgLen == 0) {
						doFireRead();
						continue;
					} else if(_msgLen > _max){
						throw new MsgLengthTooBig("the max is : " ~ to!string(_max) ~ " the length is :" ~ to!string(_msgLen));
					}
					_data = new ubyte[_msgLen];
					break;
				case ReadPOS.Body:
				{
					const size_t needLen = _msgLen - _readLen;
					const size_t canRead = len - i;
					logDebug();
					if(canRead >= needLen){
						auto tlen = i + needLen;
						_data[_readLen.._msgLen] = msg[i..tlen];
						i = tlen - 1;
						doFireRead();
					} else {
						auto tlen = _readLen + canRead;
						_data[_readLen..tlen] = msg[i..len];
						_readLen = cast(uint)tlen;
						return;
					}
				}
					break;
			}
		}
	}

	final override void write(Context ctx, ubyte[] msg, TheCallBack cback = null)
	{
		logDebug("writeln data!");
		try 
		{
			ubyte ctype = _compressType;
			auto tmsg = doCompress(ctype, msg);
			uint size = cast(uint) tmsg.length;
			if(size > _max){
				throw new MsgLengthTooBig("the max is : " ~ to!string(_max) ~ " the length is :" ~ to!string(_msgLen));
			}
			ubyte[] data = new ubyte[size + 5];
			ubyte[4] length = nativeToEndian!(littleEndian,uint)(size); 
			data[0 .. 4] = length[];
			data[4] = ctype;
			data[5 .. $] = tmsg[];
			ctx.fireWrite(new SocketStreamBuffer(data,null),null);
			if (cback)
				cback(msg, size);
		}
		catch (Exception e)
		{
			import collie.utils.exception;
			showException(e);
			if (cback)
				cback(msg, 0);
		}
	}

protected:
	ubyte[] doCompress(ref ubyte type, ubyte[] data)
	{
		return data;
	}
	
	ubyte[] unCompress(in ubyte type, ubyte[] data)
	{
		return data;
	}

private:
	enum ReadPOS : ubyte
	{
		Length_Begin,
		Length_1,
		Length_2,
		Length_End,
		Compress_Type,
		Body
	}

private:
	ubyte[] _data;
	ubyte[4] _lenByte;
	ubyte _readComType;
	uint _msgLen;
	uint _readLen;
	ReadPOS _pos = ReadPOS.Length_Begin;

	uint _max;
	ubyte _compressType;
}


unittest
{
	import collie.net;
	import kiss.net.TcpStream;
	import collie.channel.handlercontext;
	import std.stdio;
	
	ubyte[] gloaData;
	
	class Contex : HandlerContext!(ubyte[],StreamWriteBuffer)
	{
		override void fireRead(ubyte[] msg)
		{
			writeln("the msg is : ", cast(string) msg);
		}
		
		override void fireTimeOut()
		{
		}
		
		override void fireTransportActive()
		{
		}
		
		override void fireTransportInactive()
		{
		}
		
		override void fireWrite(StreamWriteBuffer msg, void delegate(StreamWriteBuffer, size_t) cback = null)
		{
			auto data = msg.sendData;
			gloaData ~= data;
			writeln("length is : ", data[0 .. 4], " \n the data is : ", cast(string)(data[4 .. $]));
		}
		
		override void fireClose()
		{
		}
		
		override @property PipelineBase pipeline()
		{
			return null;
		}
		
		override @property Transport transport()
		{
			return null;
		}
	}
	
	Contex ctx = new Contex();
	
	auto hander = new LengthBasedFrame!false(2048);
	string data = "i am a test string";
	ubyte[] tdata = cast(ubyte[]) data;
	hander.write(ctx, tdata);
	
	hander.write(ctx, gloaData);
	
	hander.read(ctx, gloaData);
	
	hander.read(ctx, gloaData[0 .. 3]);
	hander.read(ctx, gloaData[3 .. 20]);
	hander.read(ctx, gloaData[20 .. $]);
	
}