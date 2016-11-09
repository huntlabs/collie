module collie.codec.http.session.httpdownstreamsession;

import collie.codec.http.session.httpsession;
import collie.codec.http.httpmessage;
import collie.codec.http.httptansaction;
import collie.codec.http.codec.httpcodec;

final class HTTPDownstreamSession : HTTPSession
{
	this(HTTPSessionController controller,HTTPCodec codec, SessionDown down)
	{
		super(controller,codec,down);
	}

protected:
	override void setupOnHeadersComplete(ref HTTPTransaction txn,
		HTTPMessage msg)
	{
		auto handle =  _controller.getRequestHandler(txn,msg);
		if(handle is null)
		{
			try{
				import collie.codec.http.headers;
				import std.typecons;
				scope HTTPMessage rmsg = new HTTPMessage();
				rmsg.statusCode = 404;
				rmsg.statusMessage = HTTPMessage.statusText(404);
				rmsg.getHeaders.add(HTTPHeaderCode.CONNECTION,"close");
				sendHeaders(txn,rmsg,true);
				txn = null;
			}catch (Exception e){
				import collie.utils.exception;
				showException(e);
			}
		} else {
			txn.handler(handle);
			txn.onIngressHeadersComplete(msg);
		}
	}

	override bool onNativeProtocolUpgrade(StreamID stream,CodecProtocol protocol,string protocolString,HTTPMessage msg) {
		return false;
	}

}


