/*
 * Collie - An asynchronous event-driven network framework using Dlang development
 *
 * Copyright (C) 2015-2017  Shanghai Putao Technology Co., Ltd 
 *
 * Developer: putao's Dlang team
 *
 * Licensed under the Apache-2.0 License.
 *
 */
 
module collie.bootstrap.serversslconfig;

import std.string;

//import kiss.net;

version(USE_SSL)
{
    public import deimos.openssl.ssl;
	public import deimos.openssl.bio;
}
else
{
    alias SSL_CTX = int;
}

enum SSLMode
{
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

    SSL_CTX* generateSSLCtx()
    {
		if(_ctx)
			return _ctx;
		version(USE_SSL)
        {
            final switch (_mode)
            {
            case SSLMode.SSLv2v3:
					_ctx = SSL_CTX_new(SSLv23_method());
                break;
            case SSLMode.TLSv1:
					_ctx = SSL_CTX_new(TLSv1_method());
                break;
            case SSLMode.TLSv1_1:
					_ctx = SSL_CTX_new(TLSv1_1_method());
                break;
            case SSLMode.TLSv1_2:
					_ctx = SSL_CTX_new(TLSv1_2_method());
                break;
            }
			if (_ctx is null)
                return null;
			if (SSL_CTX_use_certificate_file(_ctx, toStringz(_certificateFile), SSL_FILETYPE_PEM) < 0)
            {
                error("SSL_CTX_use_certificate_file failed ! file : ", _certificateFile);
				SSL_CTX_free(_ctx);
                return null;
            }
			if (SSL_CTX_use_PrivateKey_file(_ctx, toStringz(_privateKeyFile), SSL_FILETYPE_PEM) < 0)
            {
                error("SSL_CTX_use_PrivateKey_file failed! file : ", _privateKeyFile);
				SSL_CTX_free(_ctx);
                return null;
            }
			if (SSL_CTX_check_private_key(_ctx) < 0)
            {
                error("SSL_CTX_check_private_key failed");
				SSL_CTX_free(_ctx);
                return null;
            }
        }
        return _ctx;
    }

    @property certificateFile(string file)
    {
        _certificateFile = file;
    }

    @property certificateFile()
    {
        return _certificateFile;
    }

    @property privateKeyFile(string file)
    {
        _privateKeyFile = file;
    }

    @property privateKeyFile()
    {
        return _privateKeyFile;
    }

    @property cipherList(string cliper)
    {
        _cipherList = cliper;
    }

    @property cipherList()
    {
        return _cipherList;
    }

    @property sslMode()
    {
        return _mode;
    }

private:
    string _certificateFile;
    string _privateKeyFile;
    string _cipherList;
    SSLMode _mode;
	SSL_CTX* _ctx = null;
}

version(USE_SSL)
{
    import core.sync.mutex;
    import core.thread;

    shared static this()
    {
        SSL_load_error_strings();
        SSL_library_init();
        sslmutex = new Mutex[CRYPTO_num_locks()];
        for (uint i = 0; i < sslmutex.length; ++i)
        {
            sslmutex[i] = new Mutex();
        }
        static if (OPENSSL_VERSION_NUMBER > 0x10000000L)
        {
            CRYPTO_THREADID_set_callback(&threadid_function);
        }
        else
        {
            CRYPTO_set_id_callback(&id_function);
        }
        CRYPTO_set_locking_callback(&ssl_lock_callback);
    }

    shared static ~this()
    {
        static if (OPENSSL_VERSION_NUMBER > 0x10000000L)
        {
            CRYPTO_THREADID_set_callback(null);
        }
        else
        {
            CRYPTO_set_id_callback(null);
        }
        CRYPTO_set_locking_callback(null);
    }

private:
    __gshared Mutex[] sslmutex;

extern (C):
    pragma(inline, true) ulong id_function()
    {
        return cast(ulong)(Thread.getThis.id);
    }

    void threadid_function(CRYPTO_THREADID* id)
    {
        version (Windows)
        {
            CRYPTO_THREADID_set_numeric(id, cast(uint) id_function());
        }
        else
        {
            CRYPTO_THREADID_set_numeric(id, id_function());
        }
    }

    void ssl_lock_callback(int mode, int type, const(char)* file, int line)
    {
        if (mode & CRYPTO_LOCK)
        {
            sslmutex[type].lock();
        }
        else
        {
            sslmutex[type].unlock();
        }
    }
}