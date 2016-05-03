include(UseD)
add_d_conditions(VERSION Have_collie DEBUG )
include_directories(/home/dsby/Code/dlang/work/github/collie/source/)
add_library(collie 
    /home/dsby/Code/dlang/work/github/collie/source/collie/bootstrap/clientbootstrap.d
    /home/dsby/Code/dlang/work/github/collie/source/collie/bootstrap/serverbootstrap.d
    /home/dsby/Code/dlang/work/github/collie/source/collie/buffer/SectionBuffer.d
    /home/dsby/Code/dlang/work/github/collie/source/collie/buffer/buffer.d
    /home/dsby/Code/dlang/work/github/collie/source/collie/buffer/uniquebuffer.d
    /home/dsby/Code/dlang/work/github/collie/source/collie/channel/handler.d
    /home/dsby/Code/dlang/work/github/collie/source/collie/channel/handlercontext.d
    /home/dsby/Code/dlang/work/github/collie/source/collie/channel/package.d
    /home/dsby/Code/dlang/work/github/collie/source/collie/channel/pipeline.d
    /home/dsby/Code/dlang/work/github/collie/source/collie/channel/tcpsockethandler.d
    /home/dsby/Code/dlang/work/github/collie/source/collie/socket/accept.d
    /home/dsby/Code/dlang/work/github/collie/source/collie/socket/common.d
    /home/dsby/Code/dlang/work/github/collie/source/collie/socket/eventloop.d
    /home/dsby/Code/dlang/work/github/collie/source/collie/socket/eventloopgroup.d
    /home/dsby/Code/dlang/work/github/collie/source/collie/socket/package.d
    /home/dsby/Code/dlang/work/github/collie/source/collie/socket/selector/epoll.d
    /home/dsby/Code/dlang/work/github/collie/source/collie/socket/sslsocket.d
    /home/dsby/Code/dlang/work/github/collie/source/collie/socket/tcpclient.d
    /home/dsby/Code/dlang/work/github/collie/source/collie/socket/tcpsocket.d
    /home/dsby/Code/dlang/work/github/collie/source/collie/socket/timer.d
    /home/dsby/Code/dlang/work/github/collie/source/collie/utils/functional.d
    /home/dsby/Code/dlang/work/github/collie/source/collie/utils/queue.d
    /home/dsby/Code/dlang/work/github/collie/source/collie/utils/timingwheel.d
)
target_link_libraries(collie  )
set_target_properties(collie PROPERTIES TEXT_INCLUDE_DIRECTORIES "")
