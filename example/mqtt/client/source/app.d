/*
 * Collie - An asynchronous event-driven network framework using Dlang development
 *
 * Copyright (C) 2015-2016  Shanghai Putao Technology Co., Ltd 
 *
 * Developer: putao's Dlang team
 *
 * Licensed under the Apache-2.0 License.
 *
 */
module app;

import core.thread;

import std.datetime;
import std.stdio;
import std.functional;
import std.exception;

import collie.socket;
import collie.channel;
import collie.bootstrap.client;

import collie.codec.mqtt;
import collie.utils.vector;
import std.conv;

import collie.socket.common;
import collie.socket.transport;
import collie.channel.pipeline;
import collie.channel.handlercontext;


static  string CLIENT_ID = "RANDOM_TEST_CLIENT";
static  string WILL_TOPIC = "/my_will";
static  string WILL_MESSAGE = "gone";
static  string USER_NAME = "happy_user";
static  string PASSWORD = "123_or_no_pwd";

static  int KEEP_ALIVE_SECONDS = 600;


EventLoopGroup group;

alias Pipeline!(ubyte[], MqttMsg) MqttClientPipeline;
MqttClientPipeline pipe;

class MqttClientPipelineFactory : PipelineFactory!MqttClientPipeline
{
public:
    override MqttClientPipeline newPipeline(TCPSocket sock){
        auto pipeline = MqttClientPipeline.create();
        pipeline.addBack(new TCPSocketHandler(sock));
		pipeline.addBack(new MqttEncoder());
        pipeline.finalize();
        return pipeline;
    }
}

void waitForConnect(Address addr,ClientBootstrap!MqttClientPipeline client)
{
	writeln("waitForConnect");
	import core.sync.semaphore;
	Semaphore cod = new Semaphore(0);
	client.connect(addr,(MqttClientPipeline pipe){
			if(pipe)
				writeln("connect suesss!");
			else
				writeln("connect erro!");
			cod.notify();});
	cod.wait();
	enforce(client.pipeLine,"can not connet to server!");
}


void main()
{
	group = new EventLoopGroup(1);
	group.start();
	ClientBootstrap!MqttClientPipeline client = new ClientBootstrap!MqttClientPipeline(group.at(0));
	client.tryCount(3);
	client.heartbeatTimeOut(120)
		.pipelineFactory(new shared MqttClientPipelineFactory());
	waitForConnect(new InternetAddress("127.0.0.1",8094),client);
    
    pipe = client.pipeLine;
	writeln("1  .testConnectMessageForMqtt31");
	writeln("2  .testConnectMessageForMqtt311");
	writeln("3  .testConnAckMessage");
	writeln("4  .testPublishMessage");
	writeln("5  .testPubAckMessage");
	writeln("6  .testPubRecMessage");
	writeln("7  .testPubRelMessage");
	writeln("8  .testPubCompMessage");
	writeln("9  .testSubscribeMessage");
	writeln("10 .testSubAckMessage");
	writeln("11 .testUnSubscribeMessage");
	writeln("12 .testUnsubAckMessage");
	writeln("13 .testPingReqMessage");
	writeln("14 .testPingRespMessage");
	writeln("15 .testDisconnectMessage");
    while(true)
	{
		writeln("input number : ");

		string data = readln();
		auto tmp = cast(ubyte[])data;
		data = cast(string)tmp[0..$-1];

	    auto flg = to!int(data);
		switch(flg)
		{
			case 1:
				testConnectMessageForMqtt31();
				break;
			case 2:
				testConnectMessageForMqtt311();
				break;
			case 3:
				testConnAckMessage();
				break;
			case 4:
				testPublishMessage();
				break;
			case 5:
				testPubAckMessage();
				break;
			case 6:
				testPubRecMessage();
				break;
			case 7:
				testPubRelMessage();
				break;
			case 8:
				testPubCompMessage();
				break;
			case 9:
				testSubscribeMessage();
				break;
			case 10:
				testSubAckMessage();
				break;
			case 11:
				testUnSubscribeMessage();
				break;
			case 12:
				testUnsubAckMessage();
				break;
			case 13:
				testPingReqMessage();
				break;
			case 14:
				testPingRespMessage();
				break;
			case 15:
				testDisconnectMessage();
				break;
			default:
				break;
		}
		//pipe.write(cast(ubyte[])data,null);
	}
}

//mqtt 3.1 版本  的测试连接报文 
void testConnectMessageForMqtt31()
{
	writeln("---------------testConnectMessageForMqtt31----------------");
	MqttConnectMsg message = createConnectMessage(new MqttVersion("MQIsdp",cast(byte)3));
//	ByteBuf byteBuf = MqttEncoder.doEncode(message);
//	writeln("test bytebuf readerindex : --> ",byteBuf.readerIndex()," writeindex : ",byteBuf.writerIndex()," len : ",byteBuf.length);
//	writeln(byteBuf.data);
	pipe.write(message,null);
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
	pipe.write(message,null);
}

//测试确认连接
void testConnAckMessage()  {
	writeln("---------------testConnAckMessage----------------");
	MqttConnAckMessage message = createConnAckMessage();
	pipe.write(message,null);
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
	
	pipe.write(message,null);
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
	
	pipe.write(message,null);
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
	pipe.write(message,null);
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
	
	pipe.write(message,null);
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
	pipe.write(message,null);

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
	pipe.write(message,null);

}

MqttMsg createMessageWithFixedHeader(MqttMsgType messageType) {
	return new MqttMsg(new MqttFixedHeader(messageType, false, MqttQoS.AT_MOST_ONCE, false, 0));
}
