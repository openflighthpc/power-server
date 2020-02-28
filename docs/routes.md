# API Routes Documentation

This document contain details on the Power Server API which leverages the HTTP verbs to preform its actions. The API conforms to the standards as described in [RFC 7231](https://tools.ietf.org/html/rfc7231) but does not conform to a standard REST architecture by design.

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in [BCP 14](https://tools.ietf.org/html/bcp14) \[[RFC2119](https://tools.ietf.org/html/rfc2119)\] \[[RFC8174](https://tools.ietf.org/html/rfc8174)\] when, and only when, they appear in all capitals, as shown here.

## Authorization and Headers

This application uses Json Web Tokens as to authenticate requests according to [RFC 7519](https://tools.ietf.org/html/rfc7519). The token must be sent within the `Authorization` header. The `token` MUST make an expiry claim and SHOULD NOT set any other fields. The server MUST respond `403 Forbidden` if the token is invalid, expired, or missing.

All requests must send the following header:

```
Authorization: Bearer <token>
```

## Routes

All the requests MUST be made to the root URL `/`. The different types of requests are distinguished via the HTTP verbs: `get`, `patch`, `put`, and `delete`. Each request can be ran on multiple `nodes` and/or `groups` using the query parameters of the same names. 

The `nodes` query parameter MUST only be specified once within the request URL and SHOULD meet the following format. The format is described using POSIX extended regular expressions as described in [IEEE Std 1003.1-2017](https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap09.html#tag_09_03). The `groups` param uses the same regular expression and name expansion as the `nodes`.
`^[:alnum:]+(\[[:digit:]+-[:digit:]+\])?(,[:alnum:]+(\[[:digit:]+-[:digit:]+\])?)*$`

This expression is then expanded into a list of nodes:

```
# Expanding a comma separated list
'node1,slave1,gpu1'
=> ['node1', 'slave1', 'gpu1']

# Expanding a range expression
'node[0-10]'
=> ['node0', 'node1', 'node2', ..., 'node9', 'node10']

# Expanding a range expression with padding
'node00[0-1000]'
=> ['node000', 'node001', ..., 'node010', 'node011', ..., 'node100', 'node101', ..., 'node999', 'node1000']

# Expanding a range expression with higher digit padding
'node0[10-100]'
=> ['node010', 'node011', ..., 'node099', 'node100']

# Incorrectly padding a range expression (padding within the brackets is ignored)
FlightFacade::Facades::GroupFacade::Exploding.expand_names('node[001-100]')
=> ['node1', 'node2', ..., 'node99', 'node100']

# Combining range expressions with a comma seperated list
FlightFacade::Facades::GroupFacade::Exploding.expand_names('node[1-5],node0[7-8],node10')
=> ['node1', 'node2', 'node3', 'node4', 'node5', 'node07', 'node08', 'node10']

# Removes duplicates
FlightFacade::Facades::GroupFacade::Exploding.expand_names('node[1-2],node1')
=> ['node1', 'node2']
```

This makes the final URL for all requests, where `nodes` and `groups` params are optional:
`/?nodes=<node-names>&&groups=<group-names>`

### GET Power Status

Returns a list of nodes with the power status.

```
GET /?nodes=<node-name>&&groups=<group-name>
Authorization: Bearer <token>

HTTP/1.1 200 OK
Content-Type: application/json

{
  "data": [{
    "type":"commands",
    "id":"<node-name>",
    "attributes": {
      "action": "status",
      "node-name":"<node-name>",
      "platform":"<platform>",
      "missing": <true|false>,
      "success": <true|false>,
      "running": <true|false|null>
    }
  }, ...
  ]
}
```

### PATCH Power On

Return a list of nodes which have been powered on.

```
PATCH /?nodes=<node-name>&&groups=<group-name>
Authorization: Bearer <token>

HTTP/1.1 200 OK
Content-Type: application/json

{
  "data": [{
    "type":"commands",
    "id":"<node-name>",
    "attributes": {
      "action": "power_on",
      "node-name":"<node-name>",
      "platform":"<platform>",
      "missing": <true|false>,
      "success": <true|false>
    }
  }, ...
  ]
}
```

### PUT Reboot

Return a list of nodes which have been rebooted.

```
PUT /?nodes=<node-name>&&groups=<group-name>
Authorization: Bearer <token>

HTTP/1.1 200 OK
Content-Type: application/json

{
  "data": [{
    "type":"commands",
    "id":"<node-name>",
    "attributes": {
      "action": "reboot",
      "node-name":"<node-name>",
      "platform":"<platform>",
      "missing": <true|false>,
      "success": <true|false>
    }
  }, ...
  ]
}
```

### DELETE Power Off

Return a list of nodes which have been powered off.

```
DELETE /?nodes=<node-name>&&groups=<group-name>
Authorization: Bearer <token>

HTTP/1.1 200 OK
Content-Type: application/json

{
  "data": [{
    "type":"commands",
    "id":"<node-name>",
    "attributes": {
      "action": "power_off",
      "node-name":"<node-name>",
      "platform":"<platform>",
      "missing": <true|false>,
      "success": <true|false>
    }
  }, ...
  ]
}
```

