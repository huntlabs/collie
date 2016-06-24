# Collie
An asynchronous event-driven network framework written in [dlang](http://dlang.org/).

## Require
- System : Linux (kernel >= 3.10) , FreeBSD, MacOS, Windows
- D : Compiler Version >= 2.071
- libssl and libcrypto

## TODO
- _timer and  Timing Wheel_ (__Complete__)
- _add TCP Client support_ (__Complete__)
- _SSL suport_ (__Now Only Server__)
- _add codec_ (__Complete,but Maybe need more__)
- _MAC and BSD suport (kqueue)_ (__Complete__)
- _UDP_ (__Complete,but No use the pipeline__)
- _Test Add Windows suport (select)_ (__Complete, use IOCP,not select. only tcp,not udp and ssl__)
