/*
 * Collie - An asynchronous event-driven network framework using Dlang development
 *
 * Copyright (C) 2015-2016  Shanghai Putao Technology Co., Ltd 
 *
 * Developer: putao's Dlang team
 *
 * Licensed under the Apache-2.0 License.
 *
 */
import std.stdio;
import std.experimental.logger;

import collie.channel;
import collie.codec.http;
import collie.bootstrap.server;
import collie.bootstrap.serversslconfig;
import collie.socket;

import webfrom;

debug { 
        extern(C) __gshared string[] rt_options = [ "gcopt=profile:1"];// maxPoolSize:50" ];
}

alias Pipeline!(ubyte[], HTTPResponse) HTTPPipeline;

class HttpServer : HTTPHandler
{
    override void requestHandle(HTTPRequest req, HTTPResponse rep)
    {
//         writeln("req path : ", req.Header.path());
// 
//         auto headMap = req.Header.headerMap;
//         foreach(key,value;headMap)
//         {
//               writeln("header key = ", key, "\t value = ",value);
//         }
// 	writeln("http version is : ", req.Header.httpVersion);
//         writeln("-------------------do handle ---------------------");
//         WebForm form  =  new WebForm(req);
//         writeln("-------------------form end!!!!!! ---------------------");
//         auto map = form.formMap();
//         foreach(key,value;map)
//         {
//             writeln("\tform key = ", key, "\n\t value = ",value);
//         }
//         writeln("-------------------show end!!!!!! ---------------------");
        rep.Header.setHeaderValue("content-type","text/html;charset=UTF-8");
        rep.Body.write(cast(ubyte[])"hello wrold!");
        rep.done();
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
    
 //   httpAllocator = a
    trace("log!!");
    httpConfig.headerStectionSize = 256;
    httpConfig.responseBodyStectionSize = 256;
    httpConfig.requestBodyStectionSize = 256;
    EventLoop loop = new EventLoop();
    EventLoopGroup group = new EventLoopGroup();
    auto ser = new ServerBootstrap!HTTPPipeline(loop);
    ser.childPipeline(new HTTPPipelineFactory()).heartbeatTimeOut(30)
         .group(group)
        .bind(8081);
        
    auto ser2 = new ServerBootstrap!HTTPPipeline(loop);
    ser2.childPipeline(new HTTPPipelineFactory()).heartbeatTimeOut(30)
         .group(group)
        .bind(8082);
    
        
    version (SSL) 
    {
        ServerSSLConfig ssl = new ServerSSLConfig(SSLMode.TLSv1_1);
        ssl.certificateFile("server.pem");
        ssl.privateKeyFile("server.pem");
        ser.setSSLConfig(ssl);
        ser2.setSSLConfig(ssl);
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
    ser2.start();
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
