module collie.codec.http.server.requesthandleradaptor;

import collie.codec.http.httpmessage;
import collie.codec.http.server.responsehandler;
import collie.codec.http.errocode;
import collie.codec.http.codec.wsframe;
import collie.codec.http.headers;
import collie.codec.http.server.requesthandler;
import collie.codec.http.httptansaction;

final class RequestHandlerAdaptor : 
	ResponseHandler,HTTPTransactionHandler
{
	this(RequestHandler handler)
	{
		super(handler);
	}

	override void setTransaction(HTTPTransaction txn) {
		_txn = txn;
		_upstream.setResponseHandler(this);
	}

	override void detachTransaction() {
		_txn = null;
		if(!_erro) {
			_upstream.requestComplete();
		}
		import collie.utils.memory;
		gcFree(this);
	}

	override void onHeadersComplete(HTTPMessage msg) {
		trace("onHeadersComplete , erro is : ", _erro , " _upstream is ", cast(void *)_upstream);
		if(msg.getHeaders.exists(HTTPHeaderCode.EXPECT)) {
			trace("has header EXPECT--------");
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

	override void onError(HTTPErrorCode erromsg)  {
		if(_erro) return;
		_erro = true;
		_upstream.onError(erromsg);
	}

	override void onEgressPaused() {}

	override void onEgressResumed() {}


	override void sendHeaders(HTTPMessage msg)
	{
		_responseStarted = true;
		if(_txn)
			_txn.sendHeaders(msg);
	}

	override void sendChunkHeader(size_t len){if(_txn)_txn.sendChunkHeader(len);}

	override void sendBody(ubyte[] data, bool iseom = false){if(_txn)_txn.sendBody(data,iseom);if(iseom)_responseStarted = false;}

	override void sendBody(ref HVector data,bool iseom = false) {if(_txn)_txn.sendBody(data,iseom);if(iseom)_responseStarted = false;}

	override void sendChunkTerminator(){if(_txn)_txn.sendChunkTerminator();}

	override void sendEOM(){if(_txn)_txn.sendEOM(); _responseStarted = false;}

	override void sendTimeOut() {
		if(_txn)
			_txn.sendTimeOut();
	}

	override void socketWrite(ubyte[] data,SocketWriteCallBack cback) {
		if(_txn)
			_txn.socketWrite(data,cback);
	}
private:
	HTTPTransaction _txn;
	bool _erro = false;
	bool _responseStarted = false;
}

