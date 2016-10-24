module collie.codec.http.exception;

import std.exception;

class HTTPMessageTypeException : Exception
{
	mixin basicExceptionCtors;
}