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


/// ServerStartException : CollieBoostExceotion
mixin ExceptionBuild!("ServerStart", "CollieBoost");

/// NeedPipeFactoryException : CollieBoostExceotion
mixin ExceptionBuild!("NeedPipeFactory", "CollieBoost");
