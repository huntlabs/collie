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
module collie.bootstrap.exception;

public import collie.exception;

import collie.utils.exception;

/// CollieBoostException : CollieExceotion
mixin ExceptionBuild!("CollieBoost", "Collie");

/// SSLException : CollieBoostExceotion
mixin ExceptionBuild!("SSL", "CollieBoost");

/// ServerIsRuningException : CollieBoostExceotion
mixin ExceptionBuild!("ServerIsRuning", "CollieBoost");

/// ServerIsListeningException : CollieBoostExceotion
mixin ExceptionBuild!("ServerIsListening", "CollieBoost");

//ConnectedException : CollieBoostExceotion
mixin ExceptionBuild!("Connected", "CollieBoost");
/// ServerStartException : CollieBoostExceotion
mixin ExceptionBuild!("ServerStart", "CollieBoost");

/// NeedPipeFactoryException : CollieBoostExceotion
mixin ExceptionBuild!("NeedPipeFactory", "CollieBoost");
