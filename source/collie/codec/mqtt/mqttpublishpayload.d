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
module collie.codec.mqtt.mqttpublishpayload;

class MqttPublishPayload
{
public:
	this(ubyte[] data)
	{
		// Constructor code
		_data = data;
	}

	ubyte[] publishData()
	{
		return _data;
	}
private:
	ubyte[] _data;
}

