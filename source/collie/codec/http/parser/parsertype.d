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
module collie.codec.http.parser.parsertype;

enum HTTPParserType
{
    HTTP_REQUEST,
    HTTP_RESPONSE,
    HTTP_BOTH
}


enum HTTPParserErrno
{
    /* No error */
    HPE_OK = 0, //"success")                                                  \

    /* Callback-related errors */
    HPE_CB_MessageBegin = 1, //"the on_message_begin callback failed")       \
    HPE_CB_Url = 2, // "the on_url callback failed")                           \
    HPE_CB_HeaderField = 3, //"the on_header_field callback failed")         \
    HPE_CB_HeaderValue = 4, //"the on_header_value callback failed")         \
    HPE_CB_HeadersComplete = 5, //"the on_headers_complete callback failed") \
    HPE_CB_Body = 6, //"the on_body callback failed")                         \
    HPE_CB_MessageComplete = 7, // "the on_message_complete callback failed") \
    HPE_CB_Status = 8, // "the on_status callback failed")                     \
    HPE_CB_ChunkHeader = 9, //"the on_chunk_header callback failed")         \
    HPE_CB_ChunkComplete = 10, //"the on_chunk_complete callback failed")     \

    /* Parsing-related errors */
    HPE_INVALID_EOF_STATE = 11, // "stream ended at an unexpected time")        \
    HPE_HEADER_OVERFLOW = 12, // "too many header bytes seen; overflow detected")                \
    HPE_CLOSED_CONNECTION = 13, // "data received after completed connection: close message")      \
    HPE_INVALID_VERSION = 14, // "invalid HTTP version")                        \
    HPE_INVALID_STATUS = 15, //"invalid HTTP status code")                     \
    HPE_INVALID_METHOD = 16, //"invalid HTTP method")                          \
    HPE_INVALID_URL = 17, //"invalid URL")                                     \
    HPE_INVALID_HOST = 18, //"invalid host")                                   \
    HPE_INVALID_PORT = 19, //"invalid port")                                   \
    HPE_INVALID_PATH = 20, //"invalid path")                                   \
    HPE_INVALID_QUERY_STRING = 21, //"invalid query string")                   \
    HPE_INVALID_FRAGMENT = 22, // "invalid fragment")                           \
    HPE_LF_EXPECTED = 23, //"LF character expected")                           \
    HPE_INVALID_HEADER_TOKEN = 24, //"invalid character in header")            \
    HPE_INVALID_CONTENT_LENGTH = 25, //  "invalid character in content-length header")                   \
    HPE_UNEXPECTED_CONTENT_LENGTH = 26, // "unexpected content-length header")                             \
    HPE_INVALID_CHUNK_SIZE = 27, // "invalid character in chunk size header")                       \
    HPE_INVALID_CONSTANT = 28, // "invalid constant string")                    \
    HPE_INVALID_INTERNAL_STATE = 29, //"encountered unexpected internal state")\
    HPE_STRICT = 30, // "strict mode assertion failed")                         \
    HPE_PAUSED = 31, //"parser is paused")                                     \
    HPE_UNKNOWN = 32 //"an unknown error occurred")
}

package (collie.codec.http) :

enum CR = '\r';
enum LF = '\n';

enum ubyte[] PROXY_CONNECTION = cast(ubyte[]) "proxy-connection";
enum ubyte[] CONNECTION = cast(ubyte[]) "connection";
enum ubyte[] CONTENT_LENGTH = cast(ubyte[]) "content-length";
enum ubyte[] TRANSFER_ENCODING = cast(ubyte[]) "transfer-encoding";
enum ubyte[] UPGRADE = cast(ubyte[]) "upgrade";
enum ubyte[] CHUNKED = cast(ubyte[]) "chunked";
enum ubyte[] KEEP_ALIVE = cast(ubyte[]) "keep-alive";
enum ubyte[] CLOSE = cast(ubyte[]) "close";

enum ULLONG_MAX = ulong.max;

enum string[33] error_string = [
    "success" //ok
    /* Callback-related errors */
    , "the on_message_begin callback failed" //CB_message_begin
    ,
    "the on_url callback failed" //CB_url
    , "the on_header_field callback failed" //CB_header_field
    ,
    "the on_header_value callback failed" //CB_header_value
    , "the on_headers_complete callback failed" //CB_headers_complete
    , "the on_body callback failed" //CB_body
    ,
    "the on_message_complete callback failed" //CB_message_complete
    , "the on_status callback failed" //CB_status
    , "the on_chunk_header callback failed" //CB_chunk_header
    ,
    "the on_chunk_complete callback failed" //CB_chunk_complete
    /* Parsing-related errors */
    , "stream ended at an unexpected time" //INVALID_EOF_STATE
    ,
    "too many header bytes seen; overflow detected" //HEADER_OVERFLOW
    , "data received after completed connection: close message" //CLOSED_CONNECTION
    ,
    "invalid HTTP version" //INVALID_VERSION
    , "invalid HTTP status code" //INVALID_STATUS
    , "invalid HTTP method" //INVALID_METHOD
    , "invalid URL" //INVALID_URL
    ,
    "invalid host" //INVALID_HOST
    , "invalid port" // INVALID_PORT
    , "invalid query string" //INVALID_QUERY_STRING
    , "invalid fragment" //INVALID_FRAGMENT
    ,
    "LF character expected" //LF_EXPECTED
    , "invalid character in header" //INVALID_HEADER_TOKEN
    ,
    "invalid character in content-length header" //INVALID_CONTENT_LENGTH
    , "unexpected content-length header" // UNEXPECTED_CONTENT_LENGTH
    ,
    "invalid character in chunk size header" //INVALID_CHUNK_SIZE
    , "invalid constant string" //INVALID_CONSTANT
    , "encountered unexpected internal state" //INVALID_INTERNAL_STATE
    ,
    "strict mode assertion failed" // STRICT
    , "parser is paused" //PAUSED
    , "an unknown error occurred" //UNKNOWN
];

enum HTTPParserFlags
{
    F_CHUNKED = 1 << 0,
    F_CONNECTION_KEEP_ALIVE = 1 << 1,
    F_CONNECTION_CLOSE = 1 << 2,
    F_CONNECTION_UPGRADE = 1 << 3,
    F_TRAILING = 1 << 4,
    F_UPGRADE = 1 << 5,
    F_SKIPBODY = 1 << 6,
    F_CONTENTLENGTH = 1 << 7,
    F_ZERO = 0
}

enum HTTPParserURLFields
{
    UF_SCHEMA = 0,
    UF_HOST = 1,
    UF_PORT = 2,
    UF_PATH = 3,
    UF_QUERY = 4,
    UF_FRAGMENT = 5,
    UF_USERINFO = 6,
    UF_MAX = 7
}

__gshared static const char[256] tokens = [ /*   0 nul    1 soh    2 stx    3 etx    4 eot    5 enq    6 ack    7 bel  */
0, 0, 0, 0, 0, 0, 0, 0, /*   8 bs     9 ht    10 nl    11 vt    12 np    13 cr    14 so    15 si   */
    0, 0, 0, 0, 0, 0, 0, 0, /*  16 dle   17 dc1   18 dc2   19 dc3   20 dc4   21 nak   22 syn   23 etb */
    0, 0, 0, 0, 0, 0, 0, 0, /*  24 can   25 em    26 sub   27 esc   28 fs    29 gs    30 rs    31 us  */
    0, 0, 0, 0, 0, 0, 0, 0, /*  32 sp    33  !    34  "    35  #    36  $    37  %    38  &    39  '  */
    0, '!', 0, '#', '$', '%', '&', '\'', /*  40  (    41  )    42  *    43  +    44  ,    45  -    46  .    47  /  */
    0, 0, '*', '+', 0, '-', '.', 0, /*  48  0    49  1    50  2    51  3    52  4    53  5    54  6    55  7  */
    '0',
    '1', '2', '3', '4', '5', '6', '7', /*  56  8    57  9    58  :    59  ;    60  <    61  =    62  >    63  ?  */
    '8', '9', 0, 0, 0, 0, 0, 0, /*  64  @    65  A    66  B    67  C    68  D    69  E    70  F    71  G  */
    0, 'a', 'b', 'c', 'd', 'e', 'f', 'g', /*  72  H    73  I    74  J    75  K    76  L    77  M    78  N    79  O  */
    'h', 'i',
    'j', 'k', 'l', 'm', 'n', 'o', /*  80  P    81  Q    82  R    83  S    84  T    85  U    86  V    87  W  */
    'p', 'q', 'r', 's', 't', 'u', 'v', 'w', /*  88  X    89  Y    90  Z    91  [    92  \    93  ]    94  ^    95  _  */
    'x',
    'y', 'z', 0, 0, 0, '^', '_', /*  96  `    97  a    98  b    99  c   100  d   101  e   102  f   103  g  */
    '`', 'a', 'b', 'c', 'd', 'e', 'f', 'g', /* 104  h   105  i   106  j   107  k   108  l   109  m   110  n   111  o  */
    'h',
    'i', 'j', 'k', 'l', 'm', 'n', 'o', /* 112  p   113  q   114  r   115  s   116  t   117  u   118  v   119  w  */
    'p', 'q', 'r', 's', 't', 'u', 'v', 'w',
    /* 120  x   121  y   122  z   123  {   124  |   125  }   126  ~   127 del */
    'x', 'y', 'z', 0, '|', 0, '~', 0];

__gshared static const byte[256] unhex = [-1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, -1, -1, -1,
    -1, -1, -1, -1, 10, 11, 12, 13, 14, 15, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, 10, 11, 12, 13, 14, 15, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1];

version (HTTP_PARSER_STRICT)
{
    pragma(inline,true)
    ubyte T(ubyte v)
    {
        return 0;
    }
}
else
{
    pragma(inline,true)
    ubyte T(ubyte v)
    {
        return v;
    }
}

__gshared const ubyte[32] normal_url_char = [ /*   0 nul    1 soh    2 stx    3 etx    4 eot    5 enq    6 ack    7 bel  */
0 | 0 | 0 | 0 | 0 | 0 | 0 | 0, /*   8 bs     9 ht    10 nl    11 vt    12 np    13 cr    14 so    15 si   */
    0 | T(2) | 0 | 0 | T(16) | 0 | 0 | 0, /*  16 dle   17 dc1   18 dc2   19 dc3   20 dc4   21 nak   22 syn   23 etb */
    0 | 0 | 0 | 0 | 0 | 0 | 0 | 0, /*  24 can   25 em    26 sub   27 esc   28 fs    29 gs    30 rs    31 us  */
    0 | 0 | 0 | 0 | 0 | 0 | 0 | 0, /*  32 sp    33  !    34  "    35  #    36  $    37  %    38  &    39  '  */
    0 | 2 | 4 | 0 | 16 | 32 | 64 | 128, /*  40  (    41  )    42  *    43  +    44  ,    45  -    46  .    47  /  */
    1 | 2 | 4 | 8 | 16 | 32 | 64 | 128, /*  48  0    49  1    50  2    51  3    52  4    53  5    54  6    55  7  */
    1 | 2 | 4 | 8 | 16 | 32 | 64 | 128, /*  56  8    57  9    58  :    59  ;    60  <    61  =    62  >    63  ?  */
    1 | 2 | 4 | 8 | 16 | 32 | 64 | 0, /*  64  @    65  A    66  B    67  C    68  D    69  E    70  F    71  G  */
    1 | 2 | 4 | 8 | 16 | 32 | 64 | 128, /*  72  H    73  I    74  J    75  K    76  L    77  M    78  N    79  O  */
    1 | 2 | 4 | 8 | 16 | 32 | 64 | 128, /*  80  P    81  Q    82  R    83  S    84  T    85  U    86  V    87  W  */
    1 | 2 | 4 | 8 | 16 | 32 | 64 | 128, /*  88  X    89  Y    90  Z    91  [    92  \    93  ]    94  ^    95  _  */
    1 | 2 | 4 | 8 | 16 | 32 | 64 | 128, /*  96  `    97  a    98  b    99  c   100  d   101  e   102  f   103  g  */
    1 | 2 | 4 | 8 | 16 | 32 | 64 | 128, /* 104  h   105  i   106  j   107  k   108  l   109  m   110  n   111  o  */
    1 | 2 | 4 | 8 | 16 | 32 | 64 | 128, /* 112  p   113  q   114  r   115  s   116  t   117  u   118  v   119  w  */
    1 | 2 | 4 | 8 | 16 | 32 | 64 | 128, /* 120  x   121  y   122  z   123  {   124  |   125  }   126  ~   127 del */
    1 | 2 | 4 | 8 | 16 | 32 | 64 | 0,];

enum HTTPParserState
{
    s_dead = 1 /* important that this is > 0 */

    ,
    s_start_req_or_res,
    s_res_or_resp_H,
    s_start_res,
    s_res_H,
    s_res_HT,
    s_res_HTT,
    s_res_HTTP,
    s_res_first_http_major,
    s_res_http_major,
    s_res_first_http_minor,
    s_res_http_minor,
    s_res_first_status_code,
    s_res_status_code,
    s_res_status_start,
    s_res_status,
    s_res_line_almost_done,
    s_start_req,
    s_req_method,
    s_req_spaces_before_url,
    s_req_schema,
    s_req_schema_slash,
    s_req_schema_slash_slash,
    s_req_server_start,
    s_req_server,
    s_req_server_with_at,
    s_req_path,
    s_req_query_string_start,
    s_req_query_string,
    s_req_fragment_start,
    s_req_fragment,
    s_req_http_start,
    s_req_http_H,
    s_req_http_HT,
    s_req_http_HTT,
    s_req_http_HTTP,
    s_req_first_http_major,
    s_req_http_major,
    s_req_first_http_minor,
    s_req_http_minor,
    s_req_line_almost_done,
    s_header_field_start,
    s_header_field,
    s_header_value_discard_ws,
    s_header_value_discard_ws_almost_done,
    s_header_value_discard_lws,
    s_header_value_start,
    s_header_value,
    s_header_value_lws,
    s_header_almost_done,
    s_chunk_size_start,
    s_chunk_size,
    s_chunk_parameters,
    s_chunk_size_almost_done,
    s_headers_almost_done,
    s_headers_done /* Important: 's_headers_done' must be the last 'header' state. All
   * states beyond this must be 'body' states. It is used for overflow
   * checking. See the PARSING_HEADER() macro.
   */

    ,
    s_chunk_data,
    s_chunk_data_almost_done,
    s_chunk_data_done,
    s_body_identity,
    s_body_identity_eof,
    s_message_done
}

enum HTTPParserHeaderstates
{
    h_general = 0,
    h_C,
    h_CO,
    h_CON,
    h_matching_connection,
    h_matching_proxy_connection,
    h_matching_content_length,
    h_matching_transfer_encoding,
    h_matching_upgrade,
    h_connection,
    h_content_length,
    h_transfer_encoding,
    h_upgrade,
    h_matching_transfer_encoding_chunked,
    h_matching_connection_token_start,
    h_matching_connection_keep_alive,
    h_matching_connection_close,
    h_matching_connection_upgrade,
    h_matching_connection_token,
    h_transfer_encoding_chunked,
    h_connection_keep_alive,
    h_connection_close,
    h_connection_upgrade
}

enum HTTPParserHostState
{
    s_http_host_dead = 1,
    s_http_userinfo_start,
    s_http_userinfo,
    s_http_host_start,
    s_http_host_v6_start,
    s_http_host,
    s_http_host_v6,
    s_http_host_v6_end,
    s_http_host_v6_zone_start,
    s_http_host_v6_zone,
    s_http_host_port_start,
    s_http_host_port
}
