module collie.channel.exception;

public import collie.exception;
public 

import collie.utils.exception;


/// CollieChannelException : CollieExceotion
mixin ExceptionBuild!("CollieChannel", "Collie");

/// InBoundTypeException : CollieChannelExceotion
mixin ExceptionBuild!("InBoundType", "CollieChannel");

/// OutBoundTypeException : CollieChannelExceotion
mixin ExceptionBuild!("OutBoundType", "CollieChannel");

/// PipelineEmptyException : CollieChannelExceotion
mixin ExceptionBuild!("PipelineEmpty", "CollieChannel");

/// HandlerNotInPipelineException : CollieChannelExceotion
mixin ExceptionBuild!("HandlerNotInPipeline", "CollieChannel");

/// NotHasInBoundException : CollieChannelExceotion
mixin ExceptionBuild!("NotHasInBound", "CollieChannel");

/// NotHasOutBoundException : CollieChannelExceotion
mixin ExceptionBuild!("NotHasOutBound", "CollieChannel");
