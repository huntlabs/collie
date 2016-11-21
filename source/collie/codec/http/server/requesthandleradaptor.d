module collie.codec.http.server.requesthandleradaptor;

import collie.codec.http.httpmessage;
import collie.codec.http.server.responsehandler;
import collie.codec.http.errocode;
import collie.codec.http.codec.wsframe;
import collie.codec.http.headers;
import collie.codec.http.server.requesthandler;
import collie.codec.http.httptansaction;
import collie.codec.http.server.responsebuilder;
import collie.codec.http.codec.httpcodec;

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
	}

	override void onHeadersComplete(HTTPMessage msg) {

		trace("onHeadersComplete , erro is : ", _erro , " _upstream is ", cast(void *)_upstream);
		if(msg.getHeaders.exists(HTTPHeaderCode.EXPECT)) {
			trace("has header EXPECT--------");
			string str = msg.getHeaders.getSingleOrEmpty(HTTPHeaderCode.EXPECT);
			if(!isSame(str,"100-continue")) {
				scope HTTPMessage headers = new HTTPMessage();
				headers.statusCode(417);
				headers.statusMessage("Expectation Failed");
				headers.wantsKeepAlive(false);
				_txn.sendHeadersWithEOM(headers);
				return;
			}else {
				scope HTTPMessage headers = new HTTPMessage();
				headers.statusCode(100);
				headers.statusMessage("Continue");
				_txn.sendHeaders(headers);
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

	override void onWsFrame(ref WSFrame wsf) {
		_upstream.onFrame(wsf);
	}

	override void onEgressPaused() {}

	override void onEgressResumed() {}

	override void sendHeadersWithEOM(HTTPMessage msg) {
		if(_txn)
			_txn.sendHeadersWithEOM(msg);
	}

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

	override void sendWsBinary(ubyte[] data)
	{
		if(_txn)
			_txn.sendWsBinary(this,data);
	}
	
	override void sendWsText(string data){
		if(_txn)
			_txn.sendWsText(this,data);
	}
	
	override void sendWsPing(ubyte[] data){
		if(_txn)
			_txn.sendWsPing(this,data);
	}
	
	override void sendWsPong(ubyte[] data){
		if(_txn)
			_txn.sendWsPong(this,data);
	}

	override bool onUpgtade(CodecProtocol protocol,HTTPMessage msg) {
		return _upstream.onUpgtade(protocol, msg);
	}
private:
	HTTPTransaction _txn;
	bool _erro = false;
	bool _responseStarted = false;
}

