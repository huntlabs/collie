module collie.codec.http.server.requesthandleradaptor;

import collie.codec.http.httpmessage;
import collie.codec.http.server.responsehandler;
import collie.codec.http.errocode;
import collie.codec.http.codec.wsframe;
import collie.codec.http.headers;
import collie.codec.http.server.requesthandler;
import collie.codec.http.httptansaction;

class RequestHandlerAdaptor : HTTPTransactionHandler,ResponseHandler
{
	this(RequestHandler handler)
	{
		super(handler);
	}

private:
	override void setTransaction(HTTPTransaction txn) {
		_txn = txn;
		_upstream.setResponseHandler(this);
	}

	override void detachTransaction() {
		if(!_erro) {
			_upstream.requestComplete();
		}
		// delete this
	}

	override void onHeadersComplete(HTTPMessage msg) {
		if(msg.getHeaders.exists(HTTPHeaderCode.EXPECT)) {
			string str = msg.getHeaders.getSingleOrEmpty(HTTPHeaderCode.EXPECT);
			if(!isSame(str,"100-continue")) {
//				ResponseBuilder(this)
//					.status(417, "Expectation Failed")
//						.closeConnection()
//						.sendWithEOM();
			}else {
//				ResponseBuilder(this)
//					.status(100, "Continue")
//						.send();
			}
		}
		if(!_erro)
			_upstream.onResquest(msg);
	}

	override void onBody(const ubyte[] chain) {
		_upstream.onBody(chain);
	}

	override void onChunkHeader(size_t lenght){}

	override void onChunkComplete() {}

	override void onEOM() {
		if(!_erro)
			_upstream.onEOM();
	}


private:
	HTTPTransaction _txn;
	bool _erro = false;
	bool _responseStarted = false;
}

