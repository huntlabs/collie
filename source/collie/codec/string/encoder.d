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

module collie.codec.string.encoder;

import collie.codec.messagetobyteencoder;

class StringEncoder : MessageToByteEncoder!string
{
	override ubyte[] encode(ref string msg)
	{
		return cast(ubyte[])msg.dup;
	}
}
