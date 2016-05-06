import std.stdio;
import std.experimental.logger;

import collie.channel;
import collie.codec.http;
import collie.bootstrap.server;
import collie.bootstrap.serversslconfig;
import collie.socket;

import collie.codec.http.handler;
import collie.codec.http.request;
import collie.codec.http.response;
import collie.codec.http.header;

debug { 
        extern(C) __gshared string[] rt_options = [ "gcopt=profile:1"];// maxPoolSize:50" ];
}

alias Pipeline!(ubyte[], HTTPResponse) HTTPPipeline;

class HttpServer : HTTPHandler
{
    override void doHttpHandle(HTTPRequest req, HTTPResponse rep)
    {
       // writeln("req path : ", req.header.path());
        rep.header.setHeaderValue("content-type","text/html;charset=UTF-8");

        rep.HTTPBody.write(cast(ubyte[])"hello wrold!");
        rep.sent();
    }
    
    override WebSocket newWebSocket(const HTTPHeader header)
    {
        return new EchoWebSocket();
    }
}

class HTTPPipelineFactory : PipelineFactory!HTTPPipeline
{
public:
    override HTTPPipeline newPipeline(TCPSocket sock)
    {
        auto pipeline = HTTPPipeline.create();
        pipeline.addBack(new TCPSocketHandler(sock));
        pipeline.addBack(new HttpServer());
        pipeline.finalize();
        return pipeline;
    }
}

void main()
{
    writeln("Edit source/app.d to start your project.");
    globalLogLevel(LogLevel.warning);
    
    HTTPConfig.HeaderStectionSize = 256;
    HTTPConfig.ResponseBodyStectionSize = 256;
    HTTPConfig.RequestBodyStectionSize = 256;
    EventLoop loop = new EventLoop();
    auto ser = new ServerBootstrap!HTTPPipeline(loop);
    ser.childPipeline(new HTTPPipelineFactory()).heartbeatTimeOut(30)
        .group(new EventLoopGroup)
        .bind(8080);
    version (SSL) 
    {
        ServerSSLConfig ssl = new ServerSSLConfig(SSLMode.SSLv2v3);
        ssl.certificateFile("server.pem");
        ssl.privateKeyFile("server.pem");
        ser.setSSLConfig(ssl);
    }
    
    debug {
            Timer tm = new Timer(loop);
            tm.setCallBack(delegate(){writeln("close time out : ");
        /*    import core.memory;
            GC.collect();
            GC.minimize(); */
            tm.stop();
            ser.stop();
            });
            tm.start(120 * 1000);
        }
        
    ser.waitForStop();
}


class EchoWebSocket : WebSocket
{
        override void onClose()
        {
                writeln("websocket closed");
        }

        override void onTextFrame(Frame frame)
        {
                writeln("get a text frame, is finna : ", frame.isFinalFrame, "  data is :", cast(string)frame.data);
                sendText("456789");
        //      sendBinary(cast(ubyte[])"456123");
        //      ping(cast(ubyte[])"123");
        }

        override void onPongFrame(Frame frame)
        {
                writeln("get a text frame, is finna : ", frame.isFinalFrame, "  data is :", cast(string)frame.data);
        }

        override void onBinaryFrame(Frame frame)
        {
                writeln("get a text frame, is finna : ", frame.isFinalFrame, "  data is :", cast(string)frame.data);
        }
}