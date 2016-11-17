module collie.socket.client.exception;

public import collie.exception;
import collie.socket.exception;
import collie.utils.exception;

/// CollieSocketException : CollieExceotion
mixin ExceptionBuild!("SocketClient", "CollieSocket");

/// ConnectedException : CollieSocketExceotion
//mixin ExceptionBuild!("SocketBind", "SocketClient");