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
module collie.codec.messagetobyteencoder;

import collie.channel.handler;
import collie.channel;

abstract class MessageToByteEncoder(M) : OutboundHandler!(M, byte[])
{
    ubyte[] encode(ref M msg);

    void callBack(ubyte[] data, uint len);

    override void write(Context ctx, Win msg, OutboundHandlerCallBack cback = null)
    {
        auto buf = encode(msg);
        if (buf.ptr)
        {
            ctx.fireWrite(buf, &callBack);
            if (cback)
            {
                import std.traits;

                static if (isArray!M)
                    cback(msg, M.length);
                else
                    cback(msg, M.sizeof);
            }
        }
        else
        {
            if (cback)
                cback(msg, 0);
        }

    }
}
