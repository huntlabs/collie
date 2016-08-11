module collie.socket.exception;

public import collie.exception;

class CollieSocketException : CollieException
{
	pure nothrow @nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, file, line);
	}
}

class ConnectedException : CollieSocketException
{
	pure nothrow @nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, file, line);
	}
}