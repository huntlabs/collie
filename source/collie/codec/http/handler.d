module collie.codec.http.handler;

import std.experimental.logger;
import std.experimental.allocator;
import std.stdio;
import std.typecons;
import std.digest.sha;
import std.base64;

import collie.channel;
/*.handler;
import collie.channel.handlercontext;
import collie.channel.pipeline; */
import collie.buffer;
/*.uniquebuffer;
import collie.buffer.SectionBuffer;
import collie.buffer.buffer; */

import collie.codec.http;
/*.request;
import collie.codec.http.response;
import collie.codec.http.websocket;
import collie.codec.http.header;
import collie.codec.http.config;*/

import std.socket;


abstract class HTTPHandler : Handler!(UniqueBuffer, HTTPRequest,HTTPResponse,ubyte[])
{
public:
    ~this()
    {
        import std.stdio;
        writeln("HTTPHandler ~this");
        if(_req) _req.destroy;
    }

    final override void read(Context ctx, UniqueBuffer msg)
    {
        if(_websocket)
        {
            _frame.readFrame(msg.data(),&doFrame);
        } 
        else 
        {
            if(_req is null)
            {
                _req = new HTTPRequest();
                _req.headerComplete = &reqHeaderDone;
                _req.requestComplete = &requestDone;
            }
            if(!_req.parserData(msg.data)){
                error("http parser erro :", _req.parser.errorString);
                close(ctx);
            }
        }
    }
    
    final override void write(Context ctx,HTTPResponse resp,TheCallBack back = null)
    {
        auto buffer = scoped!SectionBuffer(HTTPConfig.HeaderStectionSize,httpAllocator);
        const bool nullBody = (resp.HTTPBody.length == 0);
        if(nullBody)
        {
            resp.header.statusCode = 404;
        }
        resp.header.setHeaderValue("Content-Length",resp.HTTPBody.length);
        HTTPResponse.generateHeader(resp,buffer);

        writeStection(buffer,nullBody);
        trace("header write over, Go write body! ");
        writeStection(resp.HTTPBody(),true);
    }

    final override void timeOut(Context ctx)
    {
        trace("HTTP handle Time out!");
        close(ctx);
    }
    
    override void transportActive(Context ctx)
    {}
    
    override void transportInactive(Context ctx)
    {}
    
    void doHttpHandle(HTTPRequest req,HTTPResponse res);
    
    
    WebSocket newWebSocket(const HTTPHeader header);
    
protected:
    final void reqHeaderDone(HTTPHeader header)
    {
        trace("reqHeaderDone");
        if(header.upgrade){
            if (_res is null)
            {
                _res = new HTTPResponse();
                _res.sentCall(&responseSent);
                _res.closeCall(&responseClose);
            }
            doUpgrade();
        }
    }
    
    final void requestDone(HTTPRequest req)
    {
        try{
        
            trace("requestDone");
            import collie.socket.tcpsocket;
            TCPSocket sock = cast(TCPSocket)context.transport;
            _req.clientAddress = sock.remoteAddress();
            if(req.header.httpVersion == HTTPVersion.HTTP1_0)_shouldClose = true;
            if (_res is null)
            {
                _res = new HTTPResponse();
                _res.sentCall(&responseSent);
                _res.closeCall(&responseClose);
            }
            doHttpHandle(_req,_res);
        } catch (Exception e){
            error("handle erro! close the Socket, the erro : ",e.msg);
            close(context());
        }
    }
    
    final void responseSent(HTTPResponse resp, string file, ulong begin)
    {
        trace("responseSent");
        if(!context.transport.isAlive()) return;
        scope(exit) clear();
        if(file is null)
        {
           trace("write(context(),resp);");
           write(context(),resp);
        }
        else 
        {
            import std.file;
            auto buffer = scoped!SectionBuffer(HTTPConfig.HeaderStectionSize,httpAllocator);
            ulong size = exists(file) && isFile(file) ? getSize(file) : 0;
            size = size > begin ? size - begin : 0;
            if (size == 0)
            {
                resp.header.statusCode = 404;
                resp.header.setHeaderValue("Content-Length",0);
                HTTPResponse.generateHeader(resp,buffer);
                writeStection(buffer,true);
            } 
            else
            {
                _file = new File(file,"r");
                _file.seek(begin);
                resp.header.setHeaderValue("Content-Length",size);
                HTTPResponse.generateHeader(resp,buffer);
                writeStection(buffer,false,true);
            } 
        }
    }
    
    final void responseClose(HTTPResponse red)
    {
        clear();
        close(context());
    }
    
    
    final void freeBuffer(ubyte[] data,uint length)
    {
        httpAllocator.deallocate(data);
    }

    final void lastWrited(ubyte[] data,uint len)
    {
        httpAllocator.deallocate(data);
        if(_shouldClose)
            close(context);
    }
    
    final bool writeStection(SectionBuffer buffer, bool isLast, bool isFile = false)
    {
        trace("writeStection ,isLast = ", isLast, " the buffer length = ",buffer.length);
        import std.container.array;
        import std.functional;
        import core.stdc.string;
        
        if(buffer.length == 0){
                return false;
        }

        size_t wsize =  buffer.writeSite;
        Array!(ubyte[]) arbuffer;
        buffer.swap(&arbuffer);
        size_t wcount = arbuffer.length;
        -- wcount;
        for(uint i = 0; i < wcount ; ++i)
        {
            context.fireWrite(arbuffer[i],&freeBuffer);
        }
        ubyte[] data = arbuffer[wcount][0..wsize];
        if(isFile)
            context.fireWrite(data,&sendFile);
        else
            isLast ? context.fireWrite(data,&lastWrited) : context.fireWrite(data,&freeBuffer);
        
        return true;
    }

    pragma(inline, true);
    final void clear()
    {
        if(_req)
            _req.clear();
        if(_res)
            _res.clear();
        if(_frame) _frame.clear();
        _shouldClose = false;
    }
protected: //WebSocket
    final void sendFile(ubyte[] data,uint len)
    {
        try{
            if(_file.eof())
            {
                 httpAllocator.deallocate(data);
                 _file.close();
                 delete _file;
                 _file = null;
                 if(_shouldClose)
                    close(context());
            }
            else
            {
                if(_file.tell() == 0)
                {
                    httpAllocator.deallocate(data);
                    data = cast(ubyte[])httpAllocator.allocate(4096);
                }
                data =  _file.rawRead(data);
                context.fireWrite(data,&sendFile);
            }
        } 
        catch
        {
             httpAllocator.deallocate(data);
             close(context());
        }
        
    } 
    
    
    final void doUpgrade()
    {
        trace(" doUpgrade()");
        import std.string;
        auto header = _req.header();
        string upgrade = header.getHeaderValue("upgrade"); // "upgrade" in header.headerMap();
        string connection =   header.getHeaderValue("connection");//"connection" in header.headerMap();
        string key =  header.getHeaderValue("sec-websocket-key"); //"sec-websocket-key" in header.headerMap();
        //auto pProtocol = "sec-webSocket-protocol" in req.headers;
        string pVersion =  header.getHeaderValue("sec-websocket-version");//"sec-websocket-version" in header.headerMap();
        
        auto isUpgrade = false;

        if( connection.length > 0 ) {
                auto connectionTypes = split(connection, ",");
                foreach( t ; connectionTypes ) {
                        if( t.strip().toLower() == "upgrade" ) {
                                isUpgrade = true;
                                break;
                        }
                }
        }
        trace("isUpgrade = ",isUpgrade, "  pVersion = ", pVersion, "   upgrade = ",upgrade);
        if( !(isUpgrade && (icmp(upgrade, "websocket") == 0) && (key.length > 0 ) && (pVersion == "13") ))
        {
                _res.HTTPBody.write(cast(ubyte[])"Browser sent invalid WebSocket request.");
                _res.header.statusCode = 400;
                _shouldClose = true;
                _res.sent();
                return;
        }

        auto accept = cast(string)Base64.encode(sha1Of(key ~ WebSocketGuid));
    
        _websocket = newWebSocket(header);
        
        if(_websocket){
            import collie.socket.tcpsocket;
                _websocket._hand = this;
                TCPSocket sock = cast(TCPSocket)context.transport;
                _req.clientAddress = sock.remoteAddress();
                _frame = new HandleFrame(false);
                _res.header.statusCode = 101;
                _res.header.setHeaderValue("Sec-WebSocket-Accept",accept);
                _res.header.setHeaderValue("Connection","Upgrade");
                _res.header.setHeaderValue("Upgrade","websocket");
                _res.sent();
        } else {
                _res.HTTPBody.write(cast(ubyte[])"Browser sent invalid WebSocket request.");
                _res.header.statusCode = 400;
                _shouldClose = true;
                _res.sent();
        } 
    }

    final void doFrame(Frame frame, bool text)
    {
        if(frame.isControlFrame){
            switch (frame.opCode()) {
                case OpCode.OpCodePing:
                {//DO pong
                    ubyte[] tdata = cast(ubyte[]) httpAllocator.allocate(128);
                    auto buf = scoped!PieceBuffer(tdata);
                    _frame.pong(frame.data,buf);
                    context().fireWrite(buf.data(),&freeBuffer);
                }
                break;
                        
                case OpCode.OpCodePong:
                    _websocket.onPongFrame(frame);
                    break;
                default :
                    close(context);
                    break;
            }
        } else {
                if(text){
                        _websocket.onTextFrame(frame);
                } else {
                        _websocket.onBinaryFrame(frame);
                }
        } 
    }
    
package:
    bool ping(ubyte[] data)
    {
            if(!context().transport.isAlive()) return false;
            ubyte[] tdata = cast(ubyte[]) httpAllocator.allocate(128);
            auto buf = scoped!PieceBuffer(tdata);
            _frame.ping(data,buf);
            context().fireWrite(buf.data(),&freeBuffer);
            return true;
    }

    bool send(ubyte[] data, bool isBin)
    { 
            if(!context().transport.isAlive()) return false;
            auto buffer = scoped!SectionBuffer(HTTPConfig.ResponseBodyStectionSize,httpAllocator);
            const len = data.length + 35;
            buffer.reserve(len);
            _frame.writeFrame(data,isBin,buffer);
            return writeStection(buffer,false);
    }
    pragma(inline, true);
    void doClose(){close(context);}
private:
    HTTPRequest _req = null;
    HTTPResponse _res = null;
    WebSocket _websocket = null;
    HandleFrame _frame = null;
    bool _shouldClose = false;
    File * _file;
}

