module collie.codec.bytetomessagedecoder;

import collie.channel;

abstract class ByteToMessageDecoder(M) : InboundHandler!(ubyte[], M)
{

    bool decode(Context* ctx, ubyte[] buf, ref M result);

    override void read(Context* ctx, ubyte[] msg)
    {
        bool success = true;
        M result;
        success = decode(ctx, msg, result);
        if (success)
        {
            ctx.fireRead(result);
        }
    }
}
