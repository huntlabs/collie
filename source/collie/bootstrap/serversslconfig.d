module collie.bootstrap.serversslconfig;

public import deimos.openssl.ssl;

enum SSLMode
{
    SSLv3 = 1,
    SSLv2v3 = 3,
    TLSv1 = 4,
    TLSv1_1 = 5,
    TLSv1_2 = 6
}


class ServerSSLConfig
{
    this(SSLMode mode)
    {
        _mode = mode;
    }
    
    SSL_CTX * generateSSLCtx()
    {
        SSL_CTX * ctx = null;
        final switch (_mode)
        {
            case SSLMode.SSLv3 :
                ctx = SSL_CTX_new (SSLv3_method ());
                break;
            case SSLMode.SSLv2v3 :
                ctx = SSL_CTX_new (SSLv23_method ());
                break;
            case SSLMode.TLSv1 :
                ctx = SSL_CTX_new (TLSv1_method ());
                break;
            case  SSLMode.TLSv1_1 :
                ctx = SSL_CTX_new (TLSv1_1_method ());
                break;
            case SSLMode.TLSv1_2 :
                ctx = SSL_CTX_new (TLSv1_2_method ());
                break;
        }
        if(ctx is null) return null;
        //TODO:
        return ctx;
    }
    
    @property certificateFile(string file) { _certificateFile = file;}
    @property certificateFile(){ return _certificateFile; }
    
    @property privateKeyFile(string file){ _privateKeyFile = file; }
    @property privateKeyFile(){ return _privateKeyFile; }
    
    @property cipherList(string cliper) { _cipherList = cliper; }
    @property cipherList() { return _cipherList; }
    
    @property sslMode(){ return _mode;}
    
private:
    string _certificateFile;
    string _privateKeyFile;
    string _cipherList;
    SSLMode _mode;
}

import core.sync.mutex;
import core.thread;

shared static this()
{
    SSL_load_error_strings ();
    SSL_library_init ();
    sslmutex = new Mutex[CRYPTO_num_locks()];
    for (uint i = 0; i < sslmutex.length; ++i){
            sslmutex[i] = new Mutex();
    }
    static if(OPENSSL_VERSION_NUMBER > 0x10000000L){
            CRYPTO_THREADID_set_callback(&threadid_function);
    } else {
            CRYPTO_set_id_callback(&id_function);
    }
    CRYPTO_set_locking_callback(&ssl_lock_callback);
}

shared static ~this()
{
    static if(OPENSSL_VERSION_NUMBER > 0x10000000L){
            CRYPTO_THREADID_set_callback(null);
    } else {
            CRYPTO_set_id_callback(null);
    }
    CRYPTO_set_locking_callback(null);
}

private :
        __gshared Mutex[] sslmutex;

        
extern(C) :
ulong id_function()
{
    return Thread.getThis.id;
}

void threadid_function(CRYPTO_THREADID* id)
{
    CRYPTO_THREADID_set_numeric(id, Thread.getThis.id);
}

void ssl_lock_callback(int mode, int type, const(char) * file, int line) 
{
    if (mode & CRYPTO_LOCK) {
            sslmutex[type].lock();
    } else {
            sslmutex[type].unlock();
    }
}