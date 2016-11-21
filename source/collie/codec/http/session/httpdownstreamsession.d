module collie.codec.http.session.httpdownstreamsession;

import std.exception;

import collie.codec.http.session.httpsession;
import collie.codec.http.headers;
import collie.codec.http.codec.wsframe;
import collie.codec.http.httpmessage;
import collie.codec.http.httptansaction;
import collie.codec.http.codec.httpcodec;
import std.base64;
import std.digest.sha;

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
			} catch (Exception e){
				import collie.utils.exception;
				showException(e);
			}
		} else {
			txn.handler(handle);
			txn.onIngressHeadersComplete(msg);
		}
	}

	override void setupProtocolUpgrade(StreamID stream,CodecProtocol protocol,string protocolString,HTTPMessage msg) {
		void doErro(){
			scope HTTPMessage rmsg = new HTTPMessage();
			rmsg.statusCode = 400;
			rmsg.statusMessage = HTTPMessage.statusText(400);
			rmsg.getHeaders.add(HTTPHeaderCode.CONNECTION,"close");
			sendHeaders(txn,rmsg,true);
		}
		auto handle =  _controller.getRequestHandler(txn,msg);
		if(handle is null){
			collectException( doClose());
			return;
		}
		txn.handler(handle);
		if(protocol == CodecProtocol.init || !txn.onUpgtade(protocol, msg))
		{
			collectException( doClose());
			return;
		}
		bool rv = true;
		switch(protocol){
			case CodecProtocol.WEBSOCKET :
				rv = doUpgradeWebSocket(msg);
				break;
			default :
				rv = false;
				brek;
		}
		if(!rv)
			doErro();
	}

	bool doUpgradeWebSocket(HTTPMessage msg)
	{
		void doErro(){
			scope HTTPMessage rmsg = new HTTPMessage();
			rmsg.statusCode = 400;
			rmsg.statusMessage = HTTPMessage.statusText(400);
			rmsg.getHeaders.add(HTTPHeaderCode.CONNECTION,"close");
			sendHeaders(txn,rmsg,true);
		}

		string key = msg.getHeaders.getSingleOrEmpty(HTTPHeaderCode.SEC_WEBSOCKET_KEY);
		string ver = msg.getHeaders.getSingleOrEmpty(HTTPHeaderCode.SEC_WEBSOCKET_VERSION);
		if(ver != "13")
			return false;
		auto accept = cast(string) Base64.encode(sha1Of(key ~ WebSocketGuid));

		scope HTTPMessage rmsg = new HTTPMessage();
		rmsg.statusCode = 101;
		rmsg.statusMessage = HTTPMessage.statusText(101);
		rmsg.getHeaders.add(HTTPHeaderCode.CONNECTION,"keep-alive");
		rmsg.getHeaders.add(HTTPHeaderCode.SEC_WEBSOCKET_ACCEPT,accept);
		rmsg.getHeaders.add(HTTPHeaderCode.CONNECTION,"Upgrade");
		rmsg.getHeaders.add(HTTPHeaderCode.UPGRADE,"websocket");
		sendHeaders(txn,rmsg,true);
		//restCodeC(new 
	}

}


