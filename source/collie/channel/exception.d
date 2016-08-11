module collie.channel.exception;

public import collie.exception;

class CollieChannelException : CollieException
{
	pure nothrow @nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, file, line);
	}
}

class InBoundTypeException : CollieChannelException
{
	pure nothrow @nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, file, line);
	}
}

class OutBoundTypeException : CollieChannelException
{
	pure nothrow @nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, file, line);
	}
}


class PipelineEmptyException : CollieChannelException
{
	pure nothrow @nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, file, line);
	}
}

class HandlerNotInPipelineException : CollieChannelException
{
	pure nothrow @nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, file, line);
	}
} 


class NotHasInBoundException : CollieChannelException
{
	pure nothrow @nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, file, line);
	}
}

class NotHasOutBoundException : CollieChannelException
{
	pure nothrow @nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, file, line);
	}
}