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
module collie.codec.http.headers.httpmethod;

enum HTTPMethod
{
	HTTP_DELETE = 0,
	HTTP_GET = 1,
	HTTP_HEAD = 2,
	HTTP_POST = 3,
	HTTP_PUT = 4,
	/* pathological */
	HTTP_CONNECT = 5,
	HTTP_OPTIONS = 6,
	HTTP_TRACE = 7,
	/* WebDAV */
	HTTP_COPY = 8,
	HTTP_LOCK = 9,
	HTTP_MKCOL = 10,
	HTTP_MOVE = 11,
	HTTP_PROPFIND = 12,
	HTTP_PROPPATCH = 13,
	HTTP_SEARCH = 14,
	HTTP_UNLOCK = 15,
	HTTP_BIND = 16,
	HTTP_REBIND = 17,
	HTTP_UNBIND = 18,
	HTTP_ACL = 19,
	/* subversion */
	HTTP_REPORT = 20,
	HTTP_MKACTIVITY = 21,
	HTTP_CHECKOUT = 22,
	HTTP_MERGE = 23,
	/* upnp */
	HTTP_MSEARCH = 24,
	HTTP_NOTIFY = 25,
	HTTP_SUBSCRIBE = 26,
	HTTP_UNSUBSCRIBE = 27,
	/* RFC-5789 */
	HTTP_PATCH = 28,
	HTTP_PURGE = 29,
	/* CalDAV */
	HTTP_MKCALENDAR = 30,
	/* RFC-2068, section 19.6.1.2 */
	HTTP_LINK = 31,
	HTTP_UNLINK = 32,
	HTTP_INVAILD = 33
}

enum string[34] method_strings = [
	"DELETE", "GET", "HEAD", "POST", "PUT", /* pathological */
	"CONNECT", "OPTIONS", "TRACE",
	/* WebDAV */
	"COPY", "LOCK", "MKCOL", "MOVE", "PROPFIND", "PROPPATCH", "SEARCH",
	"UNLOCK", "BIND", "REBIND", "UNBIND", "ACL", /* subversion */
	"REPORT", "MKACTIVITY",
	"CHECKOUT", "MERGE", /* upnp */
	"MSEARCH", "NOTIFY", "SUBSCRIBE", "UNSUBSCRIBE", /* RFC-5789 */
	"PATCH", "PURGE", /* CalDAV */
	"MKCALENDAR", /* RFC-2068, section 19.6.1.2 */
	"LINK", "UNLINK", /* 无效的 */
	"INVAILD"
];