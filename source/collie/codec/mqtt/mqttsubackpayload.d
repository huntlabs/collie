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
module collie.codec.mqtt.mqttsubackpayload;

class MqttSubAckPayload 
{
public:
	 this(int[] grantedQoSLevels) {
		if (grantedQoSLevels.length == 0) {
			throw new Exception("grantedQoSLevels is empty!");
		}

		this._grantedQoSLevels = grantedQoSLevels;
	}

	 int[] grantedQoSLevels() {
		return _grantedQoSLevels;
	}

	override
	 string toString() {
		return "";
	}
private:
	  int[] _grantedQoSLevels;
}

