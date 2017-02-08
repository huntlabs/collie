
import std.array;
import std.experimental.logger;
import std.stdio;
import collie.codec.mqtt;
import collie.utils.vector;
import std.conv;

 static  string CLIENT_ID = "RANDOM_TEST_CLIENT";
 static  string WILL_TOPIC = "/my_will";
 static  string WILL_MESSAGE = "gone";
 static  string USER_NAME = "happy_user";
 static  string PASSWORD = "123_or_no_pwd";

 static  int KEEP_ALIVE_SECONDS = 600;

void main()
{
	globalLogLevel = LogLevel.warning;
	writeln("########################mqtt dlang test########################");

	testConnectMessageForMqtt31();
	testConnectMessageForMqtt311();
	testConnAckMessage();
	testPublishMessage();
	testPubAckMessage();
	testPubRecMessage();
	testPubRelMessage();
	testPubCompMessage();
	testSubscribeMessage();
	testSubAckMessage();
	testUnSubscribeMessage();
	testUnsubAckMessage();
	testPingReqMessage();
	testPingRespMessage();
	testDisconnectMessage();
}

//mqtt 3.1 版本  的测试连接报文 
 void testConnectMessageForMqtt31()
{
	writeln("---------------testConnectMessageForMqtt31----------------");
	MqttConnectMsg message = createConnectMessage(new MqttVersion("MQIsdp",cast(byte)3));
	ByteBuf byteBuf = MqttEncoder.doEncode(message);
	//writeln("test bytebuf readerindex : --> ",byteBuf.readerIndex()," writeindex : ",byteBuf.writerIndex());
	//writeln(byteBuf.data);
	MqttMsg[] mqs ;
	MqttDecoder decoder = new MqttDecoder();
	decoder.decode(byteBuf, mqs);
	
	writeln("Expected one object but got  :--> ", mqs.length);
	
	MqttConnectMsg decodedMessage = cast(MqttConnectMsg)mqs[0];

	writeln("MqttFixedHeader MqttMessageType mismatch  ",decodedMessage.fixedHeader().messageType(),"  |  " ,message.fixedHeader().messageType());
	writeln("MqttFixedHeader Qos mismatch  ",decodedMessage.fixedHeader().qosLevel(),"  |  " ,message.fixedHeader().qosLevel());

	writeln("MqttConnectVariableHeader Name mismatch ", decodedMessage.variableHeader.name(),"  |  " , message.variableHeader.name());
	writeln(
		"MqttConnectVariableHeader KeepAliveTimeSeconds mismatch ",
		decodedMessage.variableHeader.keepAliveTimeSeconds(),"  |  " ,
		message.variableHeader.keepAliveTimeSeconds());
	writeln("MqttConnectVariableHeader Version mismatch ", decodedMessage.variableHeader.mqtt_version(), "  |  " ,message.variableHeader.mqtt_version());
	writeln("MqttConnectVariableHeader WillQos mismatch ", decodedMessage.variableHeader.willQos(),"  |  " , message.variableHeader.willQos());
	
	writeln("MqttConnectVariableHeader HasUserName mismatch ", decodedMessage.variableHeader.hasUserName(),"  |  " , message.variableHeader.hasUserName());
	writeln("MqttConnectVariableHeader HasPassword mismatch ", decodedMessage.variableHeader.hasPassword(),"  |  " , message.variableHeader.hasPassword());
	writeln(
		"MqttConnectVariableHeader IsCleanSession mismatch ",
		decodedMessage.variableHeader.isCleanSession(),"  |  " ,
		message.variableHeader.isCleanSession());
	writeln("MqttConnectVariableHeader IsWillFlag mismatch ", decodedMessage.variableHeader.isWillFlag(),"  |  " , message.variableHeader.isWillFlag());
	writeln(
		"MqttConnectVariableHeader IsWillRetain mismatch ",
		decodedMessage.variableHeader.isWillRetain(),"  |  " ,
		message.variableHeader.isWillRetain());

	writeln(
		"MqttConnectPayload ClientIdentifier mismatch ",
		decodedMessage.payload().clientIdentifier(),"  |  " ,
		message.payload().clientIdentifier());
	writeln("MqttConnectPayload UserName mismatch ", decodedMessage.payload().userName(),"  |  " , message.payload().userName());
	writeln("MqttConnectPayload Password mismatch ", decodedMessage.payload().password(), "  |  " ,message.payload().password());
	writeln("MqttConnectPayload WillMessage mismatch ", decodedMessage.payload().willMessage(),"  |  " , message.payload().willMessage());
	writeln("MqttConnectPayload WillTopic mismatch ", decodedMessage.payload().willTopic(),"  |  " , message.payload().willTopic());
}

MqttConnectMsg createConnectMessage(MqttVersion mqttVersion) {
	MqttFixedHeader mqttFixedHeader =
		new MqttFixedHeader(MqttMsgType.CONNECT, false, MqttQoS.AT_MOST_ONCE, false, 0);
	MqttConnectVariableHeader mqttConnectVariableHeader =
		new MqttConnectVariableHeader(
			mqttVersion.protocolName(),
			to!int(mqttVersion.protocolLevel()),
			true,
			true,
			true,
			1,
			true,
			true,
			KEEP_ALIVE_SECONDS);
	MqttConnectPayload mqttConnectPayload =
		new MqttConnectPayload(CLIENT_ID, WILL_TOPIC, WILL_MESSAGE, USER_NAME, PASSWORD);
	
	return new MqttConnectMsg(mqttFixedHeader, mqttConnectVariableHeader, mqttConnectPayload);
}

//mqtt  3.1.1 版本  的测试连接报文 
 void testConnectMessageForMqtt311(){
	writeln("---------------testConnectMessageForMqtt311----------------");
	MqttConnectMsg message = createConnectMessage(new MqttVersion("MQTT",cast(byte)4));
	ByteBuf byteBuf = MqttEncoder.doEncode(message);

	MqttMsg[] mqs ;
	MqttDecoder decoder = new MqttDecoder();
	decoder.decode(byteBuf, mqs);
	
	writeln("Expected one object but got " ,mqs.length);

    MqttConnectMsg decodedMessage = cast(MqttConnectMsg) mqs[0];
	
	writeln("MqttFixedHeader MqttMessageType mismatch  ",decodedMessage.fixedHeader().messageType(),"  |  " ,message.fixedHeader().messageType());
	writeln("MqttFixedHeader Qos mismatch  ",decodedMessage.fixedHeader().qosLevel(),"  |  " ,message.fixedHeader().qosLevel());
	
	writeln("MqttConnectVariableHeader Name mismatch ", decodedMessage.variableHeader.name(),"  |  " , message.variableHeader.name());
	writeln(
		"MqttConnectVariableHeader KeepAliveTimeSeconds mismatch ",
		decodedMessage.variableHeader.keepAliveTimeSeconds(),"  |  " ,
		message.variableHeader.keepAliveTimeSeconds());
	writeln("MqttConnectVariableHeader Version mismatch ", decodedMessage.variableHeader.mqtt_version(), "  |  " ,message.variableHeader.mqtt_version());
	writeln("MqttConnectVariableHeader WillQos mismatch ", decodedMessage.variableHeader.willQos(),"  |  " , message.variableHeader.willQos());
	
	writeln("MqttConnectVariableHeader HasUserName mismatch ", decodedMessage.variableHeader.hasUserName(),"  |  " , message.variableHeader.hasUserName());
	writeln("MqttConnectVariableHeader HasPassword mismatch ", decodedMessage.variableHeader.hasPassword(),"  |  " , message.variableHeader.hasPassword());
	writeln(
		"MqttConnectVariableHeader IsCleanSession mismatch ",
		decodedMessage.variableHeader.isCleanSession(),"  |  " ,
		message.variableHeader.isCleanSession());
	writeln("MqttConnectVariableHeader IsWillFlag mismatch ", decodedMessage.variableHeader.isWillFlag(),"  |  " , message.variableHeader.isWillFlag());
	writeln(
		"MqttConnectVariableHeader IsWillRetain mismatch ",
		decodedMessage.variableHeader.isWillRetain(),"  |  " ,
		message.variableHeader.isWillRetain());
	
	writeln(
		"MqttConnectPayload ClientIdentifier mismatch ",
		decodedMessage.payload().clientIdentifier(),"  |  " ,
		message.payload().clientIdentifier());
	writeln("MqttConnectPayload UserName mismatch ", decodedMessage.payload().userName(),"  |  " , message.payload().userName());
	writeln("MqttConnectPayload Password mismatch ", decodedMessage.payload().password(), "  |  " ,message.payload().password());
	writeln("MqttConnectPayload WillMessage mismatch ", decodedMessage.payload().willMessage(),"  |  " , message.payload().willMessage());
	writeln("MqttConnectPayload WillTopic mismatch ", decodedMessage.payload().willTopic(),"  |  " , message.payload().willTopic());
}

//测试确认连接
 void testConnAckMessage()  {
	writeln("---------------testConnAckMessage----------------");
	MqttConnAckMessage message = createConnAckMessage();
	ByteBuf byteBuf = MqttEncoder.doEncode(message);

	MqttMsg[] mqs ;
	MqttDecoder decoder = new MqttDecoder();
	decoder.decode(byteBuf, mqs);


	writeln("Expected one object but got " ,mqs.length);

	MqttConnAckMessage decodedMessage = cast(MqttConnAckMessage) mqs[0];
	writeln("MqttFixedHeader MqttMessageType mismatch  ",decodedMessage.fixedHeader().messageType(),"  |  " ,message.fixedHeader().messageType());
	writeln("MqttFixedHeader Qos mismatch  ",decodedMessage.fixedHeader().qosLevel(),"  |  " ,message.fixedHeader().qosLevel());

	writeln(
		"MqttConnAckVariableHeader MqttConnectReturnCode mismatch ",
		decodedMessage.variableHeader().connectReturnCode(),"  |  " ,
		message.variableHeader().connectReturnCode());
}

  MqttConnAckMessage createConnAckMessage() {
	MqttFixedHeader mqttFixedHeader =
		new MqttFixedHeader(MqttMsgType.CONNACK, false, MqttQoS.AT_MOST_ONCE, false, 0);
	MqttConnAckVariableHeader mqttConnAckVariableHeader =
		new MqttConnAckVariableHeader(MqttConnectReturnCode.CONNECTION_ACCEPTED, true);
	return new MqttConnAckMessage(mqttFixedHeader, mqttConnAckVariableHeader);
}

//发布消息
 void testPublishMessage()   {
	writeln("---------------testPublishMessage----------------");
	MqttPublishMsg message = createPublishMessage();
	
	ByteBuf byteBuf = MqttEncoder.doEncode(message);
	
	MqttMsg[] mqs ;
	MqttDecoder decoder = new MqttDecoder();
	decoder.decode(byteBuf, mqs);

	writeln("Expected one object but got " ,mqs.length);

	MqttPublishMsg decodedMessage = cast(MqttPublishMsg)mqs[0];

	writeln("MqttFixedHeader MqttMessageType mismatch  ",decodedMessage.fixedHeader().messageType(),"  |  " ,message.fixedHeader().messageType());
	writeln("MqttFixedHeader Qos mismatch  ",decodedMessage.fixedHeader().qosLevel(),"  |  " ,message.fixedHeader().qosLevel());

	writeln("MqttPublishVariableHeader TopicName mismatch ", decodedMessage.variableHeader().topicName(), "  |  " ,message.variableHeader().topicName());
	writeln("MqttPublishVariableHeader MessageId mismatch ", decodedMessage.variableHeader().messageId(),"  |  " , message.variableHeader().messageId());

	writeln("PublishPayload mismatch ", cast(string)decodedMessage.payload().publishData(),"  |  " , cast(string)message.payload().publishData());
}

MqttPublishMsg createPublishMessage() {
	MqttFixedHeader mqttFixedHeader =
		new MqttFixedHeader(MqttMsgType.PUBLISH, false, MqttQoS.AT_LEAST_ONCE, true, 0);
	MqttPublishVariableHeader mqttPublishVariableHeader = new MqttPublishVariableHeader("/abc", 1234);
	ByteBuf payload = new ByteBuf;
	payload.writeBytes(cast(ubyte[])"whatever");
	writeln("publish payload : ",payload.data());
	return new MqttPublishMsg(mqttFixedHeader, mqttPublishVariableHeader, new MqttPublishPayload(payload.data()));
}

 void testMessageWithOnlyFixedHeaderAndMessageIdVariableHeader(MqttMsgType messageType)
 {
	MqttMsg message = createMessageWithFixedHeaderAndMessageIdVariableHeader(messageType);
	
	ByteBuf byteBuf = MqttEncoder.doEncode(message);
	
	MqttMsg[] mqs ;
	MqttDecoder decoder = new MqttDecoder();
	decoder.decode(byteBuf, mqs);
	
	writeln("Expected one object but got " ,mqs.length);

	MqttMsg decodedMessage = cast(MqttMsg) mqs[0];
	writeln("MqttFixedHeader MqttMessageType mismatch  ",decodedMessage.fixedHeader().messageType(),"  |  " ,message.fixedHeader().messageType());
	writeln("MqttFixedHeader Qos mismatch  ",decodedMessage.fixedHeader().qosLevel(),"  |  " ,message.fixedHeader().qosLevel());

	writeln("MqttMessageIdVariableHeader MessageId mismatch ", (cast(MqttMsgIdVariableHeader)(decodedMessage.variableHeader())).messageId(),"  |  " , (cast(MqttMsgIdVariableHeader)(message.variableHeader())).messageId());
}

 MqttMsg createMessageWithFixedHeaderAndMessageIdVariableHeader(MqttMsgType messageType) {
	MqttFixedHeader mqttFixedHeader =
		new MqttFixedHeader(
			messageType,
			false,
			messageType == MqttMsgType.PUBREL ? MqttQoS.AT_LEAST_ONCE :  MqttQoS.AT_MOST_ONCE,
			false,
			0);
	MqttMsgIdVariableHeader mqttMessageIdVariableHeader = MqttMsgIdVariableHeader.from(12345);
	return new MqttMsg(mqttFixedHeader, mqttMessageIdVariableHeader);
}

//发布确认
 void testPubAckMessage()   {
	writeln("---------------testPubAckMessage----------------");
	testMessageWithOnlyFixedHeaderAndMessageIdVariableHeader(MqttMsgType.PUBACK);
}


//发布收到
 void testPubRecMessage()   {
	writeln("---------------testPubRecMessage----------------");
	testMessageWithOnlyFixedHeaderAndMessageIdVariableHeader(MqttMsgType.PUBREC);
}

//发布释放
void testPubRelMessage()   {
	writeln("---------------testPubRelMessage----------------");
	testMessageWithOnlyFixedHeaderAndMessageIdVariableHeader(MqttMsgType.PUBREL);
}

//发布完成
 void testPubCompMessage()   {
	writeln("---------------testPubCompMessage----------------");
	testMessageWithOnlyFixedHeaderAndMessageIdVariableHeader(MqttMsgType.PUBCOMP);
}

//订阅主题
 void testSubscribeMessage()   {
	writeln("---------------testSubscribeMessage----------------");
    MqttSubscribeMsg message = createSubscribeMessage();
	ByteBuf byteBuf = MqttEncoder.doEncode(message);

	MqttMsg[] mqs ;
	MqttDecoder decoder = new MqttDecoder();
	decoder.decode(byteBuf, mqs);
	
	writeln("Expected one object but got " ,mqs.length);

	MqttSubscribeMsg decodedMessage = cast(MqttSubscribeMsg) mqs[0];
	writeln("MqttFixedHeader MqttMessageType mismatch  ",decodedMessage.fixedHeader().messageType(),"  |  " ,message.fixedHeader().messageType());
	writeln("MqttFixedHeader Qos mismatch  ",decodedMessage.fixedHeader().qosLevel(),"  |  " ,message.fixedHeader().qosLevel());

	writeln("MqttMessageIdVariableHeader MessageId mismatch ", decodedMessage.variableHeader().messageId(),"  |  " , message.variableHeader().messageId());

	MqttTopicSubscription[] expectedTopicSubscriptions = decodedMessage.payload().topicSubscriptions();
	MqttTopicSubscription[] actualTopicSubscriptions = message.payload().topicSubscriptions();
	
	writeln(
		"MqttSubscribePayload TopicSubscriptionList size mismatch ",
		expectedTopicSubscriptions.length,"  |  " , 
		actualTopicSubscriptions.length);
	for (int i = 0; i < expectedTopicSubscriptions.length; i++) {
		writeln("MqttTopicSubscription TopicName mismatch ", expectedTopicSubscriptions[i].topicName(),"  |  " , actualTopicSubscriptions[i].topicName());
		writeln(
			"MqttTopicSubscription Qos mismatch ",
			expectedTopicSubscriptions[i].qualityOfService(),"  |  " ,
			actualTopicSubscriptions[i].qualityOfService());
	}
}

MqttSubscribeMsg createSubscribeMessage() {
	MqttFixedHeader mqttFixedHeader =
		new MqttFixedHeader(MqttMsgType.SUBSCRIBE, false, MqttQoS.AT_LEAST_ONCE, true, 0);
	MqttMsgIdVariableHeader mqttMessageIdVariableHeader = MqttMsgIdVariableHeader.from(12345);
	
	MqttTopicSubscription[] topicSubscriptions ;
	topicSubscriptions ~= (new MqttTopicSubscription("/abc", MqttQoS.AT_LEAST_ONCE));
	topicSubscriptions ~= (new MqttTopicSubscription("/def", MqttQoS.AT_LEAST_ONCE));
	topicSubscriptions ~= (new MqttTopicSubscription("/xyz", MqttQoS.EXACTLY_ONCE));
	
	MqttSubscribePayload mqttSubscribePayload = new MqttSubscribePayload(topicSubscriptions);
	return new MqttSubscribeMsg(mqttFixedHeader, mqttMessageIdVariableHeader, mqttSubscribePayload);
}

//订阅确认
void testSubAckMessage()   {
	writeln("---------------testSubAckMessage----------------");
	 MqttSubAckMsg message = createSubAckMessage();

	ByteBuf byteBuf = MqttEncoder.doEncode(message);
	
	MqttMsg[] mqs ;
	MqttDecoder decoder = new MqttDecoder();
	decoder.decode(byteBuf, mqs);
	
	writeln("Expected one object but got " ,mqs.length);

	MqttSubAckMsg decodedMessage = cast(MqttSubAckMsg)mqs[0];
	writeln("MqttFixedHeader MqttMessageType mismatch  ",decodedMessage.fixedHeader().messageType(),"  |  " ,message.fixedHeader().messageType());
	writeln("MqttFixedHeader Qos mismatch  ",decodedMessage.fixedHeader().qosLevel(),"  |  " ,message.fixedHeader().qosLevel());

	writeln("MqttMessageIdVariableHeader MessageId mismatch ", decodedMessage.variableHeader().messageId(),"  |  " , message.variableHeader().messageId());

	writeln(
		"MqttSubAckPayload GrantedQosLevels mismatch ",
		decodedMessage.payload().grantedQoSLevels(),"  |  " , 
		message.payload().grantedQoSLevels());
}

MqttSubAckMsg createSubAckMessage() {
	MqttFixedHeader mqttFixedHeader =
		new MqttFixedHeader(MqttMsgType.SUBACK, false, MqttQoS.AT_MOST_ONCE, false, 0);
	MqttMsgIdVariableHeader mqttMessageIdVariableHeader = MqttMsgIdVariableHeader.from(12345);
	MqttSubAckPayload mqttSubAckPayload = new MqttSubAckPayload([1, 2, 0]);
	return new MqttSubAckMsg(mqttFixedHeader, mqttMessageIdVariableHeader, mqttSubAckPayload);
}

//取消订阅
 void testUnSubscribeMessage()   {
	writeln("---------------testUnSubscribeMessage----------------");
	 MqttUnsubscribeMsg message = createUnsubscribeMessage();
	ByteBuf byteBuf = MqttEncoder.doEncode(message);
	
	MqttMsg[] mqs ;
	MqttDecoder decoder = new MqttDecoder();
	decoder.decode(byteBuf, mqs);
	
	writeln("Expected one object but got " ,mqs.length);
	
	 MqttUnsubscribeMsg decodedMessage = cast(MqttUnsubscribeMsg) mqs[0];
	writeln("MqttFixedHeader MqttMessageType mismatch  ",decodedMessage.fixedHeader().messageType(),"  |  " ,message.fixedHeader().messageType());
	writeln("MqttFixedHeader Qos mismatch  ",decodedMessage.fixedHeader().qosLevel(),"  |  " ,message.fixedHeader().qosLevel());
	
	writeln("MqttMessageIdVariableHeader MessageId mismatch ", decodedMessage.variableHeader().messageId(),"  |  " , message.variableHeader().messageId());

	writeln(
		"MqttUnsubscribePayload TopicList mismatch ",
		decodedMessage.payload().topics(),"  |  " ,
		message.payload().topics());
}

MqttUnsubscribeMsg createUnsubscribeMessage() {
	MqttFixedHeader mqttFixedHeader =
		new MqttFixedHeader(MqttMsgType.UNSUBSCRIBE, false, MqttQoS.AT_LEAST_ONCE, true, 0);
	MqttMsgIdVariableHeader mqttMessageIdVariableHeader = MqttMsgIdVariableHeader.from(12345);
	
	string[] topics ;
	topics ~= ("/abc");
	topics ~= ("/def");
	topics ~= ("/xyz");
	
	MqttUnsubscribePayload mqttUnsubscribePayload = new MqttUnsubscribePayload(topics);
	return new MqttUnsubscribeMsg(mqttFixedHeader, mqttMessageIdVariableHeader, mqttUnsubscribePayload);
}

//取消订阅确认
void testUnsubAckMessage()   {
	writeln("---------------testUnsubAckMessage----------------");
	testMessageWithOnlyFixedHeaderAndMessageIdVariableHeader(MqttMsgType.UNSUBACK);
}

//心跳请求
 void testPingReqMessage()   {
	writeln("---------------testPingReqMessage----------------");
	testMessageWithOnlyFixedHeader(MqttMsgType.PINGREQ);
}

//心跳响应
 void testPingRespMessage()   {
	writeln("---------------testPingRespMessage----------------");
	testMessageWithOnlyFixedHeader(MqttMsgType.PINGRESP);
}

//断开连接
 void testDisconnectMessage()   {
	writeln("---------------testDisconnectMessage----------------");
	testMessageWithOnlyFixedHeader(MqttMsgType.DISCONNECT);
}

void testMessageWithOnlyFixedHeader(MqttMsgType messageType)   {
	MqttMsg message = createMessageWithFixedHeader(messageType);
	ByteBuf byteBuf = MqttEncoder.doEncode(message);
	
	MqttMsg[] mqs ;
	MqttDecoder decoder = new MqttDecoder();
	decoder.decode(byteBuf, mqs);
	
	writeln("Expected one object but got " ,mqs.length);
	
	MqttMsg decodedMessage = cast(MqttMsg) mqs[0];
	writeln("MqttFixedHeader MqttMessageType mismatch  ",decodedMessage.fixedHeader().messageType(),"  |  " ,message.fixedHeader().messageType());
	writeln("MqttFixedHeader Qos mismatch  ",decodedMessage.fixedHeader().qosLevel(),"  |  " ,message.fixedHeader().qosLevel());
}

MqttMsg createMessageWithFixedHeader(MqttMsgType messageType) {
	return new MqttMsg(new MqttFixedHeader(messageType, false, MqttQoS.AT_MOST_ONCE, false, 0));
}
