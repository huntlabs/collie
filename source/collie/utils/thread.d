module collie.utils.thread;

import core.thread;
import std.exception;

pragma(inline,true)
Thread currentThread() nothrow @trusted
{
	auto th = Thread.getThis();
	if(th is null){
		collectException(thread_attachThis(), th);
	}
	return th;
}

unittest{
	import std.stdio;
	writeln("currentThread().id ------------- " , currentThread().id);
}