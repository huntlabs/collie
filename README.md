# Collie
An asynchronous event-driven network framework written in [dlang](http://dlang.org/).

## Require
- System : Linux (kernel >= 3.10) , FreeBSD, MacOS, Windows
- D : Compiler Version >= 2.071
- libssl and libcrypto (optional,if use the ssl)

##  Support

        | __epoll__ | __kqueue__ | __iocp__  | __select__ 
--------|-----------|------------|-----------|------------ 
TCP     |     Y     |     Y      |     Y     |     Y
SSL     |     Y     |     Y      |     N     |     N
UDP     |     Y     |     Y      |     N     |     N
Timer   |     Y     |     Y      |     Y     |     Y
        Note: PipeLine is Only support TCP.
