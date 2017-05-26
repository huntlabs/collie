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
module collie.codec.http.headers.httpcommonheaders;

import collie.utils.string;

enum HTTPHeaderCode : ubyte {
	// code reserved to indicate the absence of an HTTP header
	NONE = 0,
	// code for any HTTP header name not in the list of common headers
	OTHER = 1,

	ACCEPT = 2,
	ACCEPT_CHARSET = 3,
	ACCEPT_DATETIME = 4,
	ACCEPT_ENCODING = 5,
	ACCEPT_LANGUAGE = 6,
	ACCEPT_RANGES = 7,
	ACCESS_CONTROL_ALLOW_CREDENTIALS = 8,
	ACCESS_CONTROL_ALLOW_HEADERS = 9,
	ACCESS_CONTROL_ALLOW_METHODS = 10,
	ACCESS_CONTROL_ALLOW_ORIGIN = 11,
	ACCESS_CONTROL_EXPOSE_HEADERS = 12,
	ACCESS_CONTROL_MAX_AGE = 13,
	ACCESS_CONTROL_REQUEST_HEADERS = 14,
	ACCESS_CONTROL_REQUEST_METHOD = 15,
	AGE = 16,
	ALLOW = 17,
	ALT_SVC = 18,
	AUTHORIZATION = 19,
	CACHE_CONTROL = 20,
	CONNECTION = 21,
	CONTENT_DISPOSITION = 22,
	CONTENT_ENCODING = 23,
	CONTENT_LANGUAGE = 24,
	CONTENT_LENGTH = 25,
	CONTENT_LOCATION = 26,
	CONTENT_MD5 = 27,
	CONTENT_RANGE = 28,
	CONTENT_TYPE = 29,
	COOKIE = 30,
	DNT = 31,
	DATE = 32,
	ETAG = 33,
	EXPECT = 34,
	EXPIRES = 35,
	FROM = 36,
	FRONT_END_HTTPS = 37,
	HOST = 38,
	IF_MATCH = 39,
	IF_MODIFIED_SINCE = 40,
	IF_NONE_MATCH = 41,
	IF_RANGE = 42,
	IF_UNMODIFIED_SINCE = 43,
	KEEP_ALIVE = 44,
	LAST_MODIFIED = 45,
	LINK = 46,
	LOCATION = 47,
	MAX_FORWARDS = 48,
	ORIGIN = 49,
	P3P = 50,
	PRAGMA = 51,
	PROXY_AUTHENTICATE = 52,
	PROXY_AUTHORIZATION = 53,
	PROXY_CONNECTION = 54,
	RANGE = 55,
	REFERER = 56,
	REFRESH = 57,
	RETRY_AFTER = 58,
	SERVER = 59,
	SET_COOKIE = 60,
	STRICT_TRANSPORT_SECURITY = 61,
	TE = 62,
	TIMESTAMP = 63,
	TRAILER = 64,
	TRANSFER_ENCODING = 65,
	UPGRADE = 66,
	USER_AGENT = 67,
	VIP = 68,
	VARY = 69,
	VIA = 70,
	WWW_AUTHENTICATE = 71,
	WARNING = 72,
	X_ACCEL_REDIRECT = 73,
	X_CONTENT_SECURITY_POLICY_REPORT_ONLY = 74,
	X_CONTENT_TYPE_OPTIONS = 75,
	X_FORWARDED_FOR = 76,
	X_FORWARDED_PROTO = 77,
	X_FRAME_OPTIONS = 78,
	X_POWERED_BY = 79,
	X_REAL_IP = 80,
	X_REQUESTED_WITH = 81,
	X_UA_COMPATIBLE = 82,
	X_WAP_PROFILE = 83,
	X_XSS_PROTECTION = 84,
	SEC_WEBSOCKET_KEY = 85,
	SEC_WEBSOCKET_VERSION = 86,
	SEC_WEBSOCKET_LOCATION = 87,
	SEC_WEBSOCKET_ACCEPT = 88
}

mixin(buildEnum!HTTPHeaderCode());

string capitalizeHeader(string name)
{
	import std.uni;
	import std.array;
	import std.string;
	string[] parts = name.split("_");
	for (int i = 0; i < parts.length; i++)
	{
		parts[i] = parts[i].capitalize;
	}
	return join(parts, "-");
}
private:
string buildEnum(T)()
{
	import std.uni;
	import std.array;
	import std.conv;
	struct TMPV{
		string name;
		string value; 
	}
	TMPV[][] list;
	list.length = ubyte.max;
	string codename = "enum string[] HTTPHeaderCodeName = [";
	foreach(m; __traits(derivedMembers,T))
	{
		string str = capitalizeHeader(m);
		str = str.replace("_","-");
		codename ~= "\"" ~ str ~ "\","; 
		list[str.length] ~= TMPV(str,m);
	}
	codename = codename[0..codename.length - 1];
	codename ~= "];\n ";
	string funn = "HTTPHeaderCode headersHash(string name){\n HTTPHeaderCode code = HTTPHeaderCode.OTHER; \n switch (name.length) {\n";
	foreach(size_t index,TMPV[] ls; list)
	{
		if(ls.length > 0) {
			funn ~= "case " ~ to!string(index) ~ " : {\n";
			foreach(ref TMPV st;ls)
			{
				funn ~= "if(isSameIngnoreLowUp(name,\"" ~ st.name ~ "\" )){ code = HTTPHeaderCode."~ st.value ~ "; break;}\n";
			}
			funn ~= "\n} break;\n";
		}
	}
	funn ~= "default: break;}\n return code;}\n";
	return codename ~ funn;
}


unittest
{
	assert(headersHash("age") == HTTPHeaderCode.AGE);
	assert(headersHash("Age") == HTTPHeaderCode.AGE);
	assert(headersHash("MY-HEADER") == HTTPHeaderCode.OTHER);
	assert(headersHash("DNT") == HTTPHeaderCode.DNT);
}