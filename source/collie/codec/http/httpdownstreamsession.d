module collie.codec.http.httpdownstreamsession;

import collie.codec.http.httpsession;
import collie.codec.http.httpmessage;
import collie.codec.http.httptansaction;

final class HTTPDownstreamSession : HTTPSession
{
	this(HTTPSessionController controller,HTTPCodec codec)
	{
		super(controller,codec);
	}

protected:
	void setupOnHeadersComplete(HTTPTransaction txn,
		HTTPMessage msg)
	{
		auto handle =  _controller.getRequestHandler(txn,msg);
		txn.handler(handle);
	}
}


