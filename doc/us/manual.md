## Installation

The easiest way to install WSAPI is from [LuaRocks](http://luarocks.org). Add 
[this repository](http://www.lua.inf.puc-rio.br/~mascarenhas/rocks) to your
LuaRocks' configuration and install the `wsapi` package. If you want FastCGI
support you need to have the [FastCGI dev kit](http://www.fastcgi.com/#TheDevKit)
installed, and the LuaRocks package is `wsapi-fcgi`.

The WSAPI rock copies samples, docs and support files to it's path inside your
local repository.

If you do not want to use LuaRocks follow the installation instructions below.

### UNIX-based

To build and install WSAPI you are going to need to have Lua 5.1 installed,
as well as a C compiler and the development files for
[libfcgi](http://www.fastcgi.com/#TheDevKit).
Run the included configure script, passing the name of your Lua interpreter's executable
(usually *lua*, *lua51* or *lua5.1*). Then run *make* and finally *make install*.
This last step will probably need root privileges.

### Windows

To build the Windows binaries you will need the Lua 5.1 interpreter and a version
of Visual C++ 2005 (the freely available Express edition works fine). Edit *Makefile.win*
according to the instructions there, then run *nmake -f Makefile.win* and finally
*nmake -f Makefile.win install*.

### General

To run WSAPI applications you will also need a web server such as Apache, Lighttpd, or IIS on 
Windows (Apache on Windows will also work fine).
If you want to use the Xavante connector you will need to have Xavante installed; the
easiest way to do that is to install [Kepler](http://www.keplerproject.org).

## A Simple Application

WSAPI applications are Lua functions that take an *environment* and return
a tuple with the status code, headers and an output iterator. A very simple
application is the following:

        function hello(wsapi_env)
          local headers = { ["Content-type"] = "text/html" }
        
          local function hello_text()
            coroutine.yield("&lt;html&gt;&lt;body&gt;")
            coroutine.yield("&lt;p&gt;Hello Wsapi!&lt;/p&gt;")
            coroutine.yield("&lt;p&gt;PATH_INFO: " .. wsapi_env.PATH_INFO .. "&lt;/p&gt;")
            coroutine.yield("&lt;p&gt;SCRIPT_NAME: " .. wsapi_env.SCRIPT_NAME .. "&lt;/p&gt;")
            coroutine.yield("&lt;/body&gt;&lt;/html&gt;")
          end
        
          return 200, headers, coroutine.wrap(hello_text)
        end
     
If you did previous development for the web then the code should be self-explanatory.

Applications usually not naked functions, though, but packaged inside Lua modules, and
with a `run` function that is the entry point for WSAPI, and which you pass to your
server's WSAPI connector. The generic application launchers provided with WSAPI respect
this pattern. This is how the above example would look package this way (for example,
in a *hello.lua* file:

        #!/usr/bin/env wsapi
        
        module(..., package.seeall)

        function run(wsapi_env)
          local headers = { ["Content-type"] = "text/html" }
        
          local function hello_text()
            coroutine.yield("&lt;html&gt;&lt;body&gt;")
            coroutine.yield("&lt;p&gt;Hello Wsapi!&lt;/p&gt;")
            coroutine.yield("&lt;p&gt;PATH_INFO: " .. wsapi_env.PATH_INFO .. "&lt;/p&gt;")
            coroutine.yield("&lt;p&gt;SCRIPT_NAME: " .. wsapi_env.SCRIPT_NAME .. "&lt;/p&gt;")
            coroutine.yield("&lt;/body&gt;&lt;/html&gt;")
          end
        
          return 200, headers, coroutine.wrap(hello_text)
        end

The first line tells the UNIX-based webservers such as Apache to run WSAPI's
generic CGI launcher when executing this file as a CGI script.

## Running the application

This step depends on your server and the connector you want to use.

### UNIX-like (Apache, Lighty, etc.) CGI/FastCGI

You can run *hello.lua* directly as a CGI script, through the generic CGI launcher
*wsapi*. Just give execute permission *hello.lua* and put it in a URL-accessible path with
execute permission. You should then see something like this:

        Hello Wsapi!
        PATH\_INFO: /
        SCRIPT\_NAME: /cgi-bin/hello.lua

The generic FastCGI launcher *wsapi-fcgi* can also run the *hello.lua* file
directly. Configuration depends on your web server, but you should tell it to run
*.lua* files as FastCGI scripts with *wsapi-fcgi* as the wrapper (the configuration
is analogous to the necessary for running PHP scripts with FastCGI). As an example,
this is for Apache's *mod_fcgid*:

        AddHandler fcgid-script .lua
        FCGIWrapper /usr/bin/wsapi-fcgi .lua

You can also run *hello.lua* through a launcher script specially tailored to it. The driver
script is very similar for both connectors. For CGI it can be this one (*hello.cgi*):

        #!/usr/bin/env lua

        require "wsapi.cgi"
        require "hello"
        wsapi.cgi.run(hello.run)

For FastCGI (*hello.fcgi*):

        #!/usr/bin/env lua

        require "wsapi.fastcgi"
        require "hello"
        wsapi.fastcgi.run(hello.run)

Change *lua* to the name or your Lua interpreter executable. Now flag the launcher as 
executable and put
it in a URL-accessible path that has execute permissions. Now go to your web
browser and point to the file. You should see something like this:

        Hello Wsapi!
        PATH\_INFO: /
        SCRIPT\_NAME: /cgi-bin/hello.cgi

### Windows IIS CGI/FastCGI

The generic launchers on Windows are called *wsapi.exe* and *wsapi-fcgi.exe*. You
should associate the *.lua* file extension with one of them on IIS' management console.
Then copy *hello.lua* to some URL-accessible path.

For CGI there is also a *launcher.exe* that you can rename to *hello.exe* and it
will run the *hello.cgi* application launcher (**not** the *hello.lua* application!).
Both should be in the same path, and it should be URL-accessible and have execute
permissions on IIS. You should point your browser to *hello.exe*.

## Writing WSAPI connectors

A WSAPI connector builds the environment from information passed by the web server
and calls a WSAPI application, sending
the response back to the web server. The first thing a connector needs is a way to
specify which application to run, and this is highly connector specific. Most
connectors receive the application entry point as a parameter (but the WSAPI
provides special applications called *generic launchers* as a convenience).

The environment is a Lua table containing the CGI metavariables (at minimum
the RFC3875 ones) plus any server-specific metainformation. It also contains
an *input* field, a stream for the request's data, and an *error* field,
a stream for the server's error log. The input field answers to the *read([n])*
method, where *n* is the number of bytes you want to read (or nil if you want
the whole input). The error field answers to the *write(...)* method.

The environment should return the empty string instead of nil for undefined
metavariables, and the PATH\_INFO variable should return "/" even if the path
is empty. Behavior among the connectors should be uniform: SCRIPT\_NAME should
hold the URI up to the part where you identify which application you are serving,
if applicable (again, this is highly connector specific), while PATH\_INFO
should hold the rest of the URL.

After building the environment the connector calls the application passing the environment
to it, and collecting three return values: the HTTP status code, the table with headers, and
the output iterator. The connector sends the status and headers right away to the server,
as WSAPI does not guarantee any buffering itself. After that it begins callng the iterator
and sending output to the server until it returns nil. That's it! The connectors are careful
to treat errors gracefully: if they occur before sending the status and headers they send a
500 page, if they occur while iterating over the response they append the error message
to the response.

## Conveniences for application writers

WSAPI is very low-level and just lets your application pretend that web servers
and gateway interfaces are similar, but it does not do any kind of processing/parsing
on the request, nor any buffering on the output. Most web applications need these
features, so we provide helper libraries to do it.

The first library is *wsapi.request*. This library encapsulates the environment,
parsing the request data (GET and POST) and also handling file uploads and incoming
cookies. Then there's *wsapi.response*, which offers a simpler interface (along with
buffering) for output instead of the inversion of control of the iterator. It also
lets you easily send cookies back to the browser. Finally there is *wsapi.util*,
which provides URI encoding/decoding.

These facilities make it easier to write applications, but still are very basic.
So there are also frameworks built on top of this foundation. Currently we offer
[Orbit](http://orbit.luaforge.net), which adds niceties as dispatch based on
pattern matching over the PATH\_INFO, easy serving of static content, easy access
to databases, and easy page caching, and SAPI, included in the WSAPI package as the
*wsapi.sapi* application, for running [CGILua](http://www.keplerproject.org/cgilua/)
scripts and Lua pages.

