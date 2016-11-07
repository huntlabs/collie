module collie.codec.http.server.responsehandler;

import collie.codec.http.httpmessage;
import collie.codec.http.server.requesthandler;
import collie.codec.http.errocode;
import collie.codec.http.codec.wsframe;
import collie.codec.http.httptansaction;

abstract class ResponseHandler
{
	alias SocketWriteCallBack = HTTPTransaction.Transport.SocketWriteCallBack;

	this(RequestHandler handle)
	{
		_upstream = handle;
	}

	void sendHeaders(HTTPMessage headers);

	void sendChunkHeader(size_t len);

	void sendBody(ubyte[] data,bool iseom = false);

	void sendChunkTerminator();

	void sendEOM();

	void sendTimeOut();

	void socketWrite(ubyte[],SocketWriteCallBack);

protected:
	RequestHandler _upstream;
}

