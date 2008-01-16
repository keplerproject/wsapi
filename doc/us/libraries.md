## Overview

WSAPI includes a set of helper libraries to make writing applications and web frameworks easier.
To use these libraries just `require` them in your application or framework.

## Request

**wsapi.request.new(*wsapi_env*)** - creates a new request object wrapping *wsapi_env*

**req.GET** - table with GET parameters of request

**req.POST** - table with POST parameters of request

**req.method** - request method (usually "GET" or "POST") 

**req.path_info** - PATH_INFO metavariable

**req.script_name** - SCRIPT_NAME metavariable

**req.query_string** - unparsed query string

**req.params** - union of **req.GET** and **req.POST**, built on demand

**req.cookies[*name*]** - gets value of a cookie from browser

## Response

**wsapi.response.new([*status*, *headers*, *body*])** - creates a new response
object, optionally setting an initial status code, header table and body contents

**res.status** - status code to be returned to server

**res.headers** - table with headers to be returned to server

**res[*name*]** - same as **res.headers[*name*]**, unless *name* is a field in res

**res[*name*] = _value_** - same as **res.headers[*name*] = _value_**, unless *name* is
a field in res

**res:write(*s*)** - adds *s* to the body if it is a string, if it is a table
concatenate the contents of the table and add to the body

**res:set_cookie(*name*, *value*)** - sets the value of a cookie

**res:delete_cookie(*name*)** - erases a cookie from browser

**res:finish()** - finishes response, returning status, headers and an iterator for the body

## Util

**wsapi.util.url_encode(*s*)** - encodes *s* according to RFC2396

**wsapi.util.url_decode(*s*)** - decodes *s* according to RFC2396

