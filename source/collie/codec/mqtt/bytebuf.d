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
module collie.codec.mqtt.bytebuf;

import std.stdio;
import std.conv;
import core.memory;
import std.algorithm : swap;
import kiss.container.Vector;

import core.stdc.string;

//default big end

final class ByteBuf 
{
	alias BufferVector = Vector!(ubyte); 
	
    this()
	{
		_readIndex = _writeIndex = 0;
	}

    this(ubyte[] data )
	{
		_readIndex = _writeIndex = 0;
		writeBytes(data);
	}

	~this()
	{
		clear();
	}

	void reset()
	{
		if(_buffer.length > 0)
		{
			_readIndex = 0;
			_writeIndex = cast(int)_buffer.length;
		}
	}

	ByteBuf readSlice(int len)
	{
		if(len > _buffer.length || len + _readIndex > _buffer.length)
		{
			throw new Exception("IndexOutOfBoundsException");
		}
		ubyte[] da;
		for(int i= 0 ; i < len;i++)
		{
			da ~= _buffer[_readIndex+i];
		}
		_readIndex += len;
		return new ByteBuf(da);
	}

	int readerIndex()
	{
		return _readIndex;
	}

	int writerIndex()
	{
		return _writeIndex;
	}

	// to utf-8 string
	string toString(int index,int len)
	{
		if(len > _buffer.length || index + len > _buffer.length)
		{
			writeln("IndexOutOfBoundsException -->readindex:  ",index,"read len : ",len,"buf len :",_buffer.length);
			throw new Exception("IndexOutOfBoundsException");
		}
		ubyte[] da;
		for(int i= 0 ; i < len;i++)
		{
			da ~= _buffer[index+i];
		}
		//writeln("bytebuf tostring----> ",da," ",cast(string)(cast(byte[])da));
		return cast(string)(da);
	}

	void skipBytes(int skipsize)
	{
		if(_readIndex + skipsize > _writeIndex)
		{
			writeln("_readInxde : ",_readIndex,"skipsize :",skipsize,"_writeIndex : ",_writeIndex);
			throw new Exception("IndexOutOfBoundsException");
		}
		_readIndex += skipsize;
	}

	short readUnsignedByte()
	{
		if(_readIndex > _writeIndex || _readIndex < 0)
		{
			throw new Exception("buf cannot read");
		}

		short va = cast(short)(_buffer[_readIndex] & 0xff);
		_readIndex++;
		return va;
	}

	ubyte readByte()
	{
		if(_readIndex > _writeIndex || _readIndex < 0)
		{
			throw new Exception("buf cannot read");
		}
		
		ubyte va = cast(ubyte)_buffer[_readIndex];
		_readIndex++;
		return va;
	}

	void writeByte(int value)
	{
		ubyte data = cast(ubyte)(value & 0xff);
		writeByte(data);
	
		if(_readIndex < 0)
			_readIndex = 0;
	}

	void writeByte(ubyte value)
	{
		_buffer.insertBack(value);
		_writeIndex++;
		if(_readIndex < 0)
			_readIndex = 0;
	}

	void writeShort(int value)
	{
		ubyte d1 = cast(ubyte)((value >> 8) & 0xff);
		writeByte(d1);
		ubyte d2 = cast(ubyte)(value & 0xff);
		writeByte(d2);

		if(_readIndex < 0)
			_readIndex = 0;
	}

	void writeBytes(ubyte[] value)
	{
		_buffer.insertBack(value);
		_writeIndex += value.length;
		if(_readIndex < 0)
			_readIndex = 0;
	}

	void writeBytes(ubyte[] value, int srcIndex, int length )
	{
		ubyte[] data = value[srcIndex .. srcIndex+length];
		//writeln("writeBytes ---> : ",data);
		_buffer.insertBack(data);
		_writeIndex += length;
		if(_readIndex < 0)
			_readIndex = 0;
	}

	ubyte[] data()
	{
		return _buffer.data().dup;
	}

	pragma(inline, true) final const @property size_t length()
	{
		return _buffer.length;
	}

//	pragma(inline) void opAssign( ByteBuf s)
//	{
//		this._readIndex = s._readIndex;
//		this._writeIndex = s._writeIndex;
//		this._buffer = s._buffer.dup;
//	}

		
	@property void clear()
	{
		_buffer.clear();
		_readIndex = _writeIndex = 0;
		//logDebug("\n\tclear()!!! \n");
	}
private:
	BufferVector _buffer ;
	int _readIndex;
	int _writeIndex;
}

