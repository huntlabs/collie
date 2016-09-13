module collie.utils.exception;

mixin template ExceptionCtors()
{
	@nogc @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
	{
		super(msg, file, line, next);
	}
	
	@nogc @safe pure nothrow this(string msg, Throwable next, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, file, line, next);
	}
}

mixin template ExceptionBuild(string name, string parent = "")
{
	enum buildStr = "class " ~ name ~ "Exception : " ~ parent ~ "Exception { \n\t" ~ "mixin ExceptionCtors;\n }";
	mixin(buildStr);
}

pragma(inline, true)
void throwExceptionBuild(string name = "", string file = __FILE__, size_t line = __LINE__ )(string msg)
{
	mixin("throw new " ~ name ~ "Exception(msg,\"" ~ file ~ "\"," ~ line.stringof ~ ");");
}

version(unittest)
{
	mixin ExceptionBuild!"MyTest1";
	mixin ExceptionBuild!"MyTest2";
}

unittest
{
	import std.stdio;

	try{
		throwExceptionBuild!"MyTest1"("test Exception");
	} catch (MyTest1Exception e)
	{
		writeln(e.msg);
	}
	
	try{
		throwExceptionBuild!"MyTest2"("test Exception");
	} catch (MyTest2Exception e)
	{
		writeln(e.msg);
	}
}