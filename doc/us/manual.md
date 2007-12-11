## Installation

### UNIX-based

To build and install WSAPI you are going to need to have Lua 5.1 installed,
as well as a C compiler and the development files for [libfcgi](http://www.fastcgi.com/).
Run the included configure script, passing the name of your Lua interpreter's executable
(usually *lua*, *lua51* or *lua5.1*). Then run *make* and finally *make install*.
This last step will probably need root privileges.

### Windows

To build the Windows binaries you will need the Lua 5.1 interpreter and a version
of Visual C++ 2005 (the freely available Express edition works fine). You will
also need the development files for [libfcgi](http://www.fastcgi.com). Edit *Makefile.win*
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

<pre>
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
</pre>

We hope the code is self-explanatory.

## Running the application

Put the code above in a file called *hello.lua* in a place where Lua's *require* can
find it. Now you just need to configure the appropriate connector to call the application.
This step depends on your platform and the connector you want to use.

### UNIX-based CGI/FastCGI

You will need a driver script for your application if you want to run it with CGI or
FastCGI. The driver script is very similar for both connectors. For CGI it can be this one:

<pre>
    #!/usr/bin/env lua
    require "wsapi.cgi"
    require "hello"

    cgi.run(hello)
</pre>

For FastCGI:

<pre>
    #!/usr/bin/env lua
    require "wsapi.fastcgi"
    require "hello"

    fastcgi.run(hello)
</pre>

Change *lua* to the name or your Lua interpreter executable. Now name the file appropriately
(*hello.cgi* or *hello.fcgi*, respectively, for most servers), flag it as executable and put
it in a URL-accessible path that has execute permissions (again, this is server-specific; for 
Apache it will usually be a cgi-bin directory, such as /usr/lib/cgi-bin). Now go to your web
browser and point to the file. You should see something like this:

<pre>
<p>Hello Wsapi!<br>
PATH_INFO: /<br>
SCRIPT_NAME: /cgi-bin/hello.cgi</p>
</pre>

### Windows CGI

For Windows and CGI you will also need a driver script as above, create it and
name it *hello.cgi* (here the name is very important).
Feel free to ommit the "#!" line, it does nothing on Windows. Now copy both the driver script
and *cgi.exe* to a URL-accessible path that has execute permissions, then rename
*cgi.exe* to *hello.exe*. You should now have both *hello.exe* and *hello.cgi*
in this path. Go to the web browser and point to *hello.exe*. You should see something like this: 

<pre>
<p>Hello Wsapi!<br>
PATH_INFO: /<br>
SCRIPT_NAME: /cgi-bin/hello.exe</p>
</pre>

## Writing WSAPI connectors

A WSAPI connector builds the environment and calls a WSAPI application, sending
the response to the web server. The first thing a connector needs is a way to
specify which application to run, and this is highly connector specific. CGI
and FastCGI use a driver script, for example, while the Xavante connector
loads the application in Xavante's configuration file. Then you need to build
the environment.

The environment is a Lua table containing the CGI metavariables (at minimum
the RFC3875 ones) plus any server-specific metainformation. It also contains
an *input* field, a stream for the request's data, and an *error* field,
a stream for the server's error log. The input field answers to the *read([n])*
method, where *n* is the number of bytes you want to read (or nil if you want
the whole input). The error field answers to the *write(...)* method.

The environment should return the empty string instead of nil for undefined
metavariables, and the PATH_INFO variable should return "/" even if the path
is empty. Behavior among the connectors should be uniform: SCRIPT_NAME should
hold the URI up to the part where you identify which application are serving,
if applicable (again, this is highly connector specific), while PATH_INFO
should hold the rest of the URL.

After building the environment the connector calls the application passing it,
and collects three return values: the status code, the table with headers, and
the output iterator. You can send the status and headers right away to the server,
as WSAPI does not guarantee any buffering itself. After that call the iterator
and keep sending output until it returns nil. That's it!

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
[Orbit](http://kepler-tmp.dreamhosters.com/en/Orbit), which lets you easily build
database-backed applications in the MVC style, and we'll soon offer SAPI, for
running [CGILua](http://www.keplerproject.org/cgilua/) scripts and Lua pages.
