import std.stdio;


import collie.channel;
import collie.codec.http;
import collie.bootstrap.server;
import collie.bootstrap.serversslconfig;
import collie.socket;

shared string filePath = ".";

alias Pipeline!(ubyte[], HTTPResponse) HTTPPipeline;

class HttpFileServer : HTTPHandler
{
    override void requestHandle(HTTPRequest req, HTTPResponse rep)
    {
        
       string file = req.Header.path();
       writeln("get File : ", file);
       if(file == "/")
       {
            rep.Header.statusCode = 404;
            rep.done();
       }
       else 
       {
            file  = filePath ~ file ;
            rep.Header.setHeaderValue("content-type","application/octet-stream");
            rep.done(file);
       }
        
        
    }
    
    override WebSocket newWebSocket(const HTTPHeader header)
    {
        return null;
    }
}

class HTTPPipelineFactory : PipelineFactory!HTTPPipeline
{
public:
    override HTTPPipeline newPipeline(TCPSocket sock)
    {
        auto pipeline = HTTPPipeline.create();
        pipeline.addBack(new TCPSocketHandler(sock));
        pipeline.addBack(new HttpFileServer());
        pipeline.finalize();
        return pipeline;
    }
}

void main()
{
    writeln("Edit source/app.d to start your project.");
    
    EventLoop loop = new EventLoop();
    auto ser = new ServerBootstrap!HTTPPipeline(loop);
    ser.childPipeline(new HTTPPipelineFactory()).heartbeatTimeOut(30)
        .group(new EventLoopGroup())
        .bind(8080);
        
    ser.waitForStop();
}
