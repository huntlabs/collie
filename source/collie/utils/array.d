module collie.utils.array;

auto arrayRemove(E)(ref E[] ary, E e)
{
    size_t len = ary.length;
    size_t site = 0;
    size_t rm = 0;
    for (size_t j = site; j < len; ++j)
    {
        if(ary[j] != e) {
            ary[site] = ary[j];
            site ++;
        } else {
            rm ++;
        }
    }
    len -= rm;
    ary.length = len;
    return ary;
}


unittest
{
    import std.stdio;
    
    int[] a = [0,0,0,4,5,4,0,8,0,2,0,0,0,1,2,5,8,0];
    writeln("length a  = ", a.length, "   a is : ", a);
    int[] b = a.dup;
    arrayRemove(b,0);
    writeln("length b  = ", b.length, "   b is : ", b);
    assert(b == [4, 5, 4, 8, 2, 1, 2, 5, 8]);
    
    int[] c = a.dup;
    arrayRemove(c,8);
    writeln("length c  = ", c.length, "   c is : ", c);
    
    assert(c == [0, 0, 0, 4, 5, 4, 0, 0, 2, 0, 0, 0, 1, 2, 5, 0]);
    
     int[] d = a.dup;
     arrayRemove(d,9);
     writeln("length d = ", d.length, "   d is : ", d);
     assert(d == a);
}
