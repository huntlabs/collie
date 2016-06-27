# Collie
An asynchronous event-driven network framework written in [dlang](http://dlang.org/).

## Require
- System : Linux (kernel >= 3.10) , FreeBSD, MacOS, Windows
- D : Compiler Version >= 2.071
- libssl and libcrypto

##  Support

 ||  ||  ||  |
  || __TCP__ || Y || Y || Y || Y ||
  || __UDP__ || Y || N || N || N ||
  || __Timer__ || Y || Y || Y || Y ||

        | __epoll__ | __kqueue__ | __iocp__  | __select__ 
--------|-----------|------------|-----------|------------ 
TCP     |     Y     |     Y      |     Y     |     Y
UDP     |     Y     |     N      |     N     |     N
Timer   |     Y     |     Y      |     Y     |     Y
        Note: PipeLine is Only support TCP.
