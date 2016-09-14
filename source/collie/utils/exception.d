module collie.utils.exception;

public import std.exception : basicExceptionCtors;

mixin template ExceptionBuild(string name, string parent = "")
{
	enum buildStr = "class " ~ name ~ "Exception : " ~ parent ~ "Exception { \n\t" ~ "mixin basicExceptionCtors;\n }";
	mixin(buildStr);
}

pragma(inline, true)
void throwExceptionBuild(string name = "", string file = __FILE__, size_t line = __LINE__ )(string msg = "")
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