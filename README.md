# Collie
An asynchronous event-driven network framework written in [dlang](http://dlang.org/), like [netty](http://netty.io/) framework in D.

## Require
- System : Linux (kernel >= 3.10) , FreeBSD, MacOS, Windows
- D : Compiler Version >= 2.071
- libssl and libcrypto (optional,if use the ssl)

##  Support

function  |   epoll   |   kqueue   |   iocp    |   select 
----------|-----------|------------|-----------|------------ 
TCP       |     Y     |     Y      |     Y     |     Y
SSL       |     Y     |     Y      |     N     |     N
UDP       |     Y     |     Y      |     Y     |     Y
Timer     |     Y     |     Y      |     Y     |     Y
