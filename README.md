# Collie
An asynchronous event-driven network framework written in [dlang](http://dlang.org/).
Collie is a library that makes it easy to build protocols, application clients, and application servers.
It's like [wangle](https://github.com/facebook/wangle/) and [netty](http://netty.io/), but written in D programing language.

## Require
- System : Linux (kernel >= 3.10) , FreeBSD, MacOS
- D : Compiler Version >= 2.071
- libssl and libcrypto

## TODO
- _timer and  Timing Wheel_ (__Complete__)
- _add TCP Client support_ (__Complete__)
- _SSL suport_ (__Now Only Server__)
- _add codec_ (__Complete,but Maybe need more__)
- _MAC and BSD suport (kqueue)_ (__Complete__)
- _UDP_ (__Complete,but No use the pipeline__)
- Test Add Windows suport (select)
