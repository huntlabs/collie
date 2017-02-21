module collie.codec.string.decoder;

import collie.channel.handler;
import collie.codec.bytetomessagedecoder;

class StringDecoder : ByteToMessageDecoder!string
{
	override bool decode(Context ctx, ubyte[] buf, ref string result)
	{
		result = cast(string) buf;

		return true;
	}
}
