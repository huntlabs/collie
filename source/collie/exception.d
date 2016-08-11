module collie.exception;

class CollieException : Exception
{
	pure nothrow @nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, file, line);
	}
}
