module collie.socket.server.exception;

public import collie.exception;
import collie.socket.exception;
import collie.utils.exception;

/// CollieSocketException : CollieExceotion
mixin ExceptionBuild!("SocketServer", "CollieSocket");

/// ConnectedException : CollieSocketExceotion
mixin ExceptionBuild!("SocketBind", "SocketServer");