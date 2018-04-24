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
module collie.codec.http.server.responsehandler;

import collie.codec.http.httpmessage;
import collie.codec.http.server.requesthandler;
import collie.codec.http.errocode;
import collie.codec.http.codec.wsframe;
import collie.codec.http.httptansaction;
import kiss.net;
import kiss.event;

abstract class ResponseHandler
{
	this(RequestHandler handle)
	{
		_upstream = handle;
	}

	void sendHeaders(HTTPMessage headers);

	void sendHeadersWithEOM(HTTPMessage headers);

	void sendChunkHeader(size_t len);

	void sendBody(in ubyte[] data,bool iseom = false);

	void sendChunkTerminator();

	void sendEOM();

	void sendTimeOut();

	final void socketWrite(ubyte[] data, DataWrittenHandler cback)
	{
		socketWrite(new SocketStreamBuffer(data,cback));
	}

	void socketWrite(StreamWriteBuffer buffer);

	void sendWsData(OpCode code,ubyte[] data);

protected:
	RequestHandler _upstream;
}

