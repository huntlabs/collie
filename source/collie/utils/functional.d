module collie.utils.functional;

public import std.functional;
public import std.traits;
import std.typecons;
import std.typetuple;

auto  bind(T,Args...)(auto ref T fun,Args args) if (isCallable!(T))
{
    alias FUNTYPE = Parameters!(fun);
    static if(is(Args == void)) 
    {
        static if(isDelegate!T)
            return fun;
        else 
            return toDelegate(fun);
    } 
    else static if(FUNTYPE.length > args.length)
    {
        alias DTYPE = FUNTYPE[args.length..$];
        return 
            delegate(DTYPE ars){
                TypeTuple!(FUNTYPE) value;
                value[0..args.length] = args[];
                value[args.length..$] = ars[];
                return fun(value);
            };
    } 
    else 
    {
        return delegate(){return fun(args);};
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

  //  void main()
    {
        auto tdel = bind(&listRun);
        tdel(9);
        bind(&listRun2,4)(5);
        bind(&listRun2,40,50)();
        
        AA a = new AA();
        bind(&a.dshow,5,"hahah")(20.05);
        
        Thread[4] _thread;
        Thread[4] _thread2;
        // AA a = new AA();
        
        dooo(_thread,_thread2,a);
        
        foreach(i;0..4)
        {
            _thread[i].start();
        }
        
        foreach(i;0..4)
        {
            _thread2[i].start();
        }

    }

}
