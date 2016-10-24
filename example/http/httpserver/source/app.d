/*
 * Collie - An asynchronous event-driven network framework using Dlang development
 *
 * Copyright (C) 2015-2016  Shanghai Putao Technology Co., Ltd 
 *
 * Developer: putao's Dlang team
 *
 * Licensed under the Apache-2.0 License.
 *
 */
import std.stdio;
import std.experimental.logger;
import std.exception;

import collie.channel;
import collie.bootstrap.server;
import collie.bootstrap.serversslconfig;
import collie.socket;
import collie.codec.http;
import collie.codec.http.server;

import webfrom;

debug { 
        extern(C) __gshared string[] rt_options = [ "gcopt=profile:1"];// maxPoolSize:50" ];
}

class MyHandler : RequestHandler
{
	void onResquest(HTTPMessage headers) nothrow
	{
		_header = headers;
		collectException({
				writeln("---new HTTP request!");
				writeln("path is : ", _header.url);
			});
	}

	void onBody(const ubyte[] data) nothrow
	{}

	void onEOM() nothrow
	{}

	void requestComplete() nothrow
	{}

private:
	HTTPMessage _header;
}

void main()
{
    
    writeln("Edit source/app.d to start your project.");
    globalLogLevel(LogLevel.warning);
    
 
}
