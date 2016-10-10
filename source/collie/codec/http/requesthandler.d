module collie.codec.http.requesthandler;

import std.experimental.logger;
import std.experimental.allocator;
import std.stdio;
import std.typecons;
import std.digest.sha;
import std.base64;

import collie.channel;
import collie.buffer;
import collie.codec.http.parser;


//class RequestHandler : Handler!(ubyte[], HTTPRequest, HTTPResponse, ubyte[])
//{
//	this()
//	{
//		// Constructor code
//	}
//private:
//	HTTPParser _parser = void;
//}

