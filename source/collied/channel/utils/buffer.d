/* Copyright collied.org 
*/


module collied.channel.utils.buffer;
import core.memory;

/** 记录位置的buffer
    @author : Putao‘s Collie Team
    @date : 2016.1
*/
struct WriteBuffer
{
private:
     /** 存储数组的ubyte数组 */
	ubyte[] _data = null;
public:
    /** 记录位置的buffer的有效开始位 */
    size_t _start = 0;

     /** 获取当前buffer的有效数据 */
    ubyte[] data ()
    {
            return _data[_start .. $];
    }

	bool isInVaild(){
		return (_data is null);
	}

	void clear(){
		_data = null;
		_start = 0;
	}

    /** 获取当前buffer的有效的字节大小 */
    size_t dataSize ()
   {
		return _data.length - _start;
   }

	this(ubyte[] data)
	{
		_data = data;
	}

	ubyte[] allData()
	{
		return _data;
	}
};
