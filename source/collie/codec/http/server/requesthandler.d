module collie.codec.http.server.requesthandler;

import collie.codec.http.httpmessage;
import collie.codec.http.server.responsehandler;
import collie.codec.http.errocode;
import collie.codec.http.codec.wsframe;

abstract class RequestHandler
{
	void setResponseHandler(ResponseHandler handler) nothrow {
		_downstream = handler;
	}

	/**
   * Invoked when we have successfully fetched headers from client. This will
   * always be the first callback invoked on your handler.
   */
	void onResquest(HTTPMessage headers) nothrow;

	/**
   * Invoked when we get part of body for the request.
   */
	void onBody(const ubyte[] data) nothrow;

	/**
   * Invoked when we finish receiving the body.
   */
	void onEOM() nothrow;

	/**
   * Invoked when request processing has been completed and nothing more
   * needs to be done. This may be a good place to log some stats and
   * clean up resources. This is distinct from onEOM() because it is
   * invoked after the response is fully sent. Once this callback has been
   * received, `downstream_` should be considered invalid.
   */
	void requestComplete() nothrow;

	/**
   * Request failed. Maybe because of read/write error on socket or client
   * not being able to send request in time.
   *
   * NOTE: Can be invoked at any time (except for before onRequest).
   *
   * No more callbacks will be invoked after this. You should clean up after
   * yourself.
   */
	void onError(HTTPErrorCode code) nothrow
	{}

	void onFrame(ref WSFrame frame) nothrow
	{}

	void onPing(ref WSFrame frame) nothrow
	{}

	void onPong(ref WSFrame frame) nothrow
	{}

protected:
	ResponseHandler _downstream;
}

