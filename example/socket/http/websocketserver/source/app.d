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
import std.typecons;
import std.functional;

import collie.socket;
import collie.codec.http;
import collie.codec.http.server;
import collie.codec.http.server.websocket;

debug { 
        extern(C) __gshared string[] rt_options = [ "gcopt=profile:1"];// maxPoolSize:50" ];
}

class MyHandler : IWebSocket
{
	override void onClose(ubyte[] data)
	{
		writeln("websocket closed");
	}
	override void onText(string frame)
	{
		writeln("websocket onText : ", frame);
		sendText(frame);
	}
	override void onPong(ubyte[] frame)
	{
		writeln("websocket onPong : ", frame);
	}

	override void onBinary(ubyte[] frame)
	{
		writeln("websocket onBinary : ", frame);
		sendBinary(frame);
	}

	override void onErro(HTTPErrorCode code)
	{
		writeln("websocket error : ", code);
	}
}


RequestHandler newHandler(RequestHandler,HTTPMessage)
{

	 auto handler = new MyHandler();
	trace("----------newHandler, handle is : ", cast(void *)handler);
	return handler;
}

void main()
{
    
    writeln("Edit source/app.d to start your project.");
    //globalLogLevel(LogLevel.warning);
	trace("----------");
	HTTPServerOptions option = new HTTPServerOptions();
	option.handlerFactories.insertBack(toDelegate(&newHandler));
	option.threads = 2;

	HTTPServerOptions.IPConfig ipconfig ;
	ipconfig.address = new InternetAddress("0.0.0.0", 8081);

	HttpServer server = new HttpServer(option);
	server.addBind(ipconfig);
	server.start();
}
