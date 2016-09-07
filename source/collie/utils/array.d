module collie.utils.array;

void arrayRemove(E)(ref E[] ary, E e)
{
	size_t len = ary.length;
	void removeAt(size_t site)
	{
		size_t rm = 1;
		for (size_t j = site + 1; j < len; ++j)
		{
			if(ary[j] != e) {
				ary[site] = ary[j];
				site ++;
			} else {
				rm ++;
			}
		}
		len -= rm;
	}
	
	for(size_t i = 0; i < len; ++i)
	{
		if(ary[i] == e)
			removeAt(i);
	}
	ary.length = len;
}

unittest
{
	int[] a = [0,0,0,4,5,4,0,8,0,2,0,0,0,1,2,5,8,0];
	writeln("length a  = ", a.length, "   a is : ", a);
	int[] b = a.dup;
	arrayRemove(b,0);
	assert(b == [4, 5, 4, 8, 2, 1, 2, 5, 8]);
	
	int[] c = a.dup;
	arrayRemove(c,8);
	assert(c == [0, 0, 0, 4, 5, 4, 0, 0, 2, 0, 0, 0, 1, 2, 5, 0]);
}
