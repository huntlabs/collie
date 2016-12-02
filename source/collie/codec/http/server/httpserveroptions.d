module collie.codec.http.server.httpserveroptions;

import collie.utils.vector;
import collie.codec.http.httpmessage;
import collie.codec.http.server.requesthandler;
import collie.codec.http.codec.httpcodec;
import collie.codec.http.httptansaction;

import std.socket;


class HTTPServerOptions
{
	alias RequestHandlerFactory = RequestHandler delegate(RequestHandler,HTTPMessage);
	alias HTTPCodecFactory = HTTPCodec delegate(string,TransportDirection);
	alias HVector = Vector!(RequestHandlerFactory);

	size_t threads = 1;

	HVector handlerFactories;

	size_t timeOut = 30;// seconds

	uint listenBacklog = 1024;

	size_t maxHeaderSize = 60 * 1024;

	struct IPConfig
	{
		Address address;
		//HTTPCodecFactory codecFactory = null;
		//Protocol protocol;
		bool enableTCPFastOpen = false;
		uint fastOpenQueueSize = 10000;
	}
}

