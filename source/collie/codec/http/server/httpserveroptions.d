/*
 * Collie - An asynchronous event-driven network framework using Dlang development
 *
 * Copyright (C) 2015-2017  Shanghai Putao Technology Co., Ltd 
 *
 * Developer: putao's Dlang team
 *
 * Licensed under the Apache-2.0 License.
 *
 */
module collie.codec.http.server.httpserveroptions;

import collie.codec.http.codec.httpcodec;
import collie.codec.http.httpmessage;
import collie.codec.http.httptansaction;
import collie.codec.http.server.requesthandler;
import collie.utils.vector;
import std.socket;

version(USE_SSL){
	import collie.bootstrap.serversslconfig;
}


class HTTPServerOptions
{
	alias RequestHandlerFactory = RequestHandler delegate(RequestHandler,HTTPMessage);
	alias HTTPCodecFactory = HTTPCodec delegate(string,TransportDirection);
	alias HVector = Vector!(RequestHandlerFactory);
	this(){
		handlerFactories  = HVector(2);
	}

	size_t threads = 1;

	HVector handlerFactories;

	size_t timeOut = 30;// seconds

	uint listenBacklog = 1024;

	size_t maxHeaderSize = 60 * 1024;

	version(USE_SSL){
		ServerSSLConfig ssLConfig;
	}

	struct IPConfig
	{
		Address address;
		//HTTPCodecFactory codecFactory = null;
		//Protocol protocol;
		bool enableTCPFastOpen = false;
		uint fastOpenQueueSize = 10000;
	}
}

