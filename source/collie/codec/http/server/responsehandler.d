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

abstract class ResponseHandler
{
	alias SocketWriteCallBack = HTTPTransaction.Transport.SocketWriteCallBack;
	alias HVector = HTTPTransaction.HVector;

	this(RequestHandler handle)
	{
		_upstream = handle;
	}

	void sendHeaders(HTTPMessage headers);

	void sendHeadersWithEOM(HTTPMessage headers);

	void sendChunkHeader(size_t len);

	void sendBody(ubyte[] data,bool iseom = false);

	void sendBody(ref HVector data,bool iseom = false);

	void sendChunkTerminator();

	void sendEOM();

	void sendTimeOut();

	void socketWrite(ubyte[],SocketWriteCallBack);

	void sendWsData(OpCode code,ubyte[] data);

protected:
	RequestHandler _upstream;
}

