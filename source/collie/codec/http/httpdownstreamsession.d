module collie.codec.http.httpdownstreamsession;

import collie.codec.http.httpsession;
import collie.codec.http.httpmessage;
import collie.codec.http.httptansaction;
import collie.codec.http.codec.httpcodec;

final class HTTPDownstreamSession : HTTPSession
{
	this(HTTPSessionController controller,HTTPCodec codec)
	{
		super(controller,codec);
	}

protected:
	override void setupOnHeadersComplete(HTTPTransaction txn,
		HTTPMessage msg)
	{
		auto handle =  _controller.getRequestHandler(txn,msg);
		txn.handler(handle);
	}

	override bool onNativeProtocolUpgrade(StreamID stream,CodecProtocol protocol,string protocolString,HTTPMessage msg) {
		return false;
	}

}


