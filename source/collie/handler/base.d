module collie.handler.base;

import collie.channel.pipeline;

enum HandleType {
	outHandle,
	inHandle,
	allHandle
}

interface BeseHandle {
	HandleType handleType();
}

interface OutHandle {
	void outEvent(OutEvent event);
}

interface InHandle {
	void inEvent(InEvent event);
}

abstract class Handler : OutHandle, InHandle, BeseHandle {
	this(PiPeline pip) { _pipeline = pip; }
	final HandleType handleType() { return HandleType.allHandle; }

	override void inEvent(InEvent event) {
		event.up();
	}

	override void outEvent(OutEvent event) {
		event.down();
	}

	final @property const(PiPeline) pipeline() const { return _pipeline; }
private:
	PiPeline _pipeline;
};

abstract class InHander : InHandle , BeseHandle {
	final HandleType handleType() { return HandleType.inHandle; }

	override void inEvent(InEvent event) {
		event.up();
	}
};

abstract class OutHander : OutHandle,BeseHandle {
	this(PiPeline pip) { _pipeline = pip; }
	final HandleType handleType() { return HandleType.outHandle; }

	override void outEvent(OutEvent event) {
		event.down();
	}

	final @property const(PiPeline) pipeline() const { return _pipeline; }
private:
	PiPeline _pipeline;
};
