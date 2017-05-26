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
module collie.codec.messagetobyteencoder;

import collie.channel.handler;
import collie.channel;

abstract class MessageToByteEncoder(M) : OutboundHandler!(M, ubyte[])
{
    ubyte[] encode(ref M msg);

    void callBack(ubyte[] data, size_t len);

    override void write(Context ctx, win msg, OutboundHandlerCallBack cback = null)
    {
        auto buf = encode(msg);
        if (buf.ptr)
        {
            ctx.fireWrite(buf, &callBack);
            if (cback)
            {
                import std.traits;

                static if (isArray!M)
                    cback(msg, msg.length);
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
