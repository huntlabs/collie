module collie.utils.functional;

public import std.functional;
public import std.traits;

auto bind(T, Args...)(auto ref T fun, Args args) if (isCallable!(T))
{
    static if (is(Args == void))
    {
        static if (isDelegate!T)
            return fun;
        else
            return toDelegate(fun);
    }
    else
    {
        return delegate() { return fun(forward!args); };
    }
}

unittest
{
    
    import std.stdio;
    import core.thread;
    
    class AA
    {
        void show(int i)
        {
            writeln("i = ", i); // the value is not(0,1,2,3), it all is 2.
        }

        void show(int i, int b)
        {
            b += i * 10;
            writeln("b = ", b); // the value is not(0,1,2,3), it all is 2.
        }

        void aa()
        {
            writeln("aaaaaaaa ");
        }
    }

    void listRun(int i)
    {
        writeln("i = ", i);
    }

    void list()
    {
        writeln("bbbbbbbbbbbb");
    }

    void main()
    {
        Thread[4] _thread;
        Thread[4] _thread2;
        AA a = new AA();
        foreach (i; 0 .. 4)
        {
            auto th = new Thread(bind(&a.aa)); //bind!(void delegate(int,int))(&a.show,i,i));
            _thread[i] = th;
            auto th2 = new Thread(bind(&list)); //&listRun,(i + 10)));
            _thread2[i] = th2;
        }

        foreach (i; 0 .. 4)
        {
            _thread[i].start();
        }

        foreach (i; 0 .. 4)
        {
            _thread2[i].start();
        }

    }

}
