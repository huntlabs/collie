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
module collie.codec.lengthfieldbasedframe;

import std.bitmanip;
import std.experimental.logger;

import collie.channel;
import collie.channel.handler;
import collie.channel.handlercontext;

/// The Pack format
/// header: ubytes 4 "00 00 00 00" -> uint 
/// Compress Type: ubyte one "00"
/// the data is a data.

class LengthFieldBasedFrame(bool littleEndian = false) : HandlerAdapter!(ubyte[])
{
    this(uint max, ubyte compressType = 0x00)
    {
        _max = max;
        _compressType = compressType;
    //    clear();
    }

    final override void read(Context ctx, ubyte[] msg)
    {
        readPack(msg, ctx);
    }

    final override void write(Context ctx, ubyte[] msg, TheCallBack cback = null)
    {
        trace("writeln data!");
        try 
        {
            ubyte ctype = _compressType;
            auto tmsg = doCompress(ctype, msg);
            uint size = cast(uint) tmsg.length;
            ubyte[] data = new ubyte[size + 5];
            static if (littleEndian)
            {
                ubyte[4] length = nativeToLittleEndian(size); 
            }
            else
            {
                ubyte[4] length = nativeToBigEndian(size); 
            }
            data[0 .. 4] = length[];
            data[4] = ctype;
            data[5 .. $] = tmsg[];
            ctx.fireWrite(data,&callBack);
            if (cback)
                cback(msg, size);
        }
        catch (Exception e)
        {
            error("write erro: ",e.msg);
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

    void callBack(ubyte[] data,uint size)
    {}
    
protected:
    final void readPack(ubyte[] data, Context ctx)
    {
        if (data.length == 0)
            return;
        if (_size == 0)
        {
            uint rang = readPackSize(data);
            if (rang > 0)
            {
                if (rang < cast(uint) data.length)
                {
                    data = data[rang .. $];
                    if (_size == 0)
                    {
                        ctx.fireRead(_packData); // the size is 0;
                        clear();
                        readPack(data, ctx);
                        return;
                    }
                }
                else
                {
                    return;
                }
            }
            else
            {
                return;
            }
        }

        uint size = cast(uint) data.length;
        uint tsize = _size - _readSize;
        if (size >= tsize)
        {
            _packData[_readSize .. $] = data[0 .. tsize];
            _packData = unCompress(_packSize[4], _packData);
            ctx.fireRead(_packData);
            clear();
            data = data[tsize .. $];
            readPack(data, ctx);
        }
        else
        {
            _packData[_readSize .. (_readSize + size)] = data[];
            _readSize += size;
        }
    }

    final uint readPackSize(ref ubyte[] data)
    {
        if (_pSize == 0x05 || _size > 0)
            return 0;
        uint size = cast(uint) data.length;
        ubyte i;
        for (i = 0x00; _pSize < 0x05 && i < size; ++i, ++_pSize)
        {
            _packSize[_pSize] = data[i];
        }
        if (_pSize == 0x05)
        {
            ubyte[4] len;
            len[] = _packSize[0 .. 4];
            static if (littleEndian)
            {
                _size = littleEndianToNative!uint(len); //littleEndianToNative
            }
            else
            {
                _size = bigEndianToNative!uint(len); //
            }
            _readSize = 0;
            if (_size == 0)
            {
                return i;
            }
            if (_size > _max)
            {
                return 0;
            }
            _packData = new ubyte[_size];
            return i;
        }
        else
        {
            return 0;
        }
    }

    final void clear()
    {
        _readSize = 0;
        _pSize = 0x00;
        _size = 0;
        _packData = null;
    }
private:
    ubyte[] _packData;
    ubyte[5] _packSize;
    uint _size;
    uint _readSize;
    ubyte _pSize;
    uint _max;
    ubyte _compressType;
}

unittest
{
    import collie.socket.common;
    import std.stdio;

    ubyte[] gloaData;

    class Contex : HandlerContext!(ubyte[], ubyte[])
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

        override void fireWrite(ubyte[] msg, void delegate(ubyte[], uint) cback = null)
        {
            gloaData ~= msg;
            writeln("length is : ", msg[0 .. 4], " \n the data is : ", cast(string)(msg[4 .. $]));
        }

        override void fireClose()
        {
        }

        override @property PipelineBase pipeline()
        {
            return null;
        }

        override @property AsyncTransport transport()
        {
            return null;
        }
    }

    Contex ctx = new Contex();

    auto hander = new LengthFieldBasedFrame!false(2048);
    string data = "i am a test string";
    ubyte[] tdata = cast(ubyte[]) data;
    hander.write(ctx, tdata);

    hander.write(ctx, gloaData);

    hander.read(ctx, gloaData);

    hander.read(ctx, gloaData[0 .. 3]);
    hander.read(ctx, gloaData[3 .. 20]);
    hander.read(ctx, gloaData[20 .. $]);

}
