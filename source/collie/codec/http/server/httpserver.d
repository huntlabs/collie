module collie.codec.http.server.httpserver;

import collie.codec.http.httpsession;
import collie.codec.http.httptansaction;

class HTTPServer : HTTPSessionController
{
	this()
	{
		// Constructor code
	}

	HTTPTransactionHandler getRequestHandler(HTTPTransaction txn, HTTPMessage msg)
	{

	}
}


final class HTTPController : HTTPSessionController
{
	alias SessionCallBack = void delegate(HTTPSession);

	HTTPTransactionHandler getRequestHandler(HTTPTransaction txn, HTTPMessage msg)
	{}
	
	void attachSession(HTTPSession session){
		if(_attach)
			_attach(session);
	}

	void detachSession(HTTPSession session){
		if(_detach)
			_detach(session);
	}

	void onSessionCodecChange(HTTPSession session) {
		if(_changeCode)
			_changeCode(session);
	}
private:
	SessionCallBack _attach;
	SessionCallBack _detach;
	SessionCallBack _changeCode;
}