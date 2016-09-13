module collie.socket.exception;

public import collie.exception;
import collie.utils.exception;

/// CollieSocketException : CollieExceotion
mixin ExceptionBuild!("CollieSocket", "Collie");

/// ConnectedException : CollieSocketExceotion
mixin ExceptionBuild!("Connected", "CollieSocket");
