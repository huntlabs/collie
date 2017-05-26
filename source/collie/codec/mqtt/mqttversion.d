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
module collie.codec.mqtt.mqttversion;

import std.array;

class MqttVersion
{
	this(string protocolname,byte protocolLevel)
	{
		_name = protocolname;
		_level = protocolLevel;
	}

	string protocolName()
	{
		return _name;
	}

	byte protocolLevel()
	{
		return _level;
	}

	static MqttVersion fromProtocolNameAndLevel(string protocolname,byte protocolLevel)
	{
		foreach(MqttVersion v; _mqtt_versions)
		{
			if(v.protocolName() == protocolname && v.protocolLevel() == protocolLevel)
				return v;
		}
		throw new Exception("unknown protocol name");
	}


private :
	string _name;
	byte _level;

}

__gshared  MqttVersion[] _mqtt_versions= [new MqttVersion("MQIsdp",cast(byte)3), new MqttVersion("MQTT",cast(byte)4)];