# Collie
An asynchronous event-driven network framework written in [dlang](http://dlang.org/), like [netty](http://netty.io/) framework in D.

## Require
- System : Linux (kernel >= 3.10) , FreeBSD, MacOS, Windows
- D : Compiler Version >= 2.071
- libssl and libcrypto (optional,if use the ssl)

##  Support

Feature   |   epoll   |   kqueue   |   iocp    |   select 
----------|-----------|------------|-----------|------------ 
TCP       |     Y     |     Y      |     Y     |     Y
SSL*      |     Y     |     Y      |     Y     |     Y
UDP       |     Y     |     Y      |     Y     |     Y
Timer     |     Y     |     Y      |     Y     |     Y
        NOte: Now , the ssl only support as server. not support as a client.
## Contact:
* QQ Group : **184183224**
