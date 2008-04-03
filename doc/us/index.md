## Overview

*WSAPI* is an API that abstracts the web server from Lua web applications. By coding
against WSAPI your application can run on any of the supported servers and
interfaces (currently CGI, FastCGI and Xavante, on Windows and UNIX-based systems).
WSAPI also provides a set of helper libraries that help with request processing
and output buffering. You can also write applications that act as filters that
provide some kind of service to other applications, such as authentication,
file uploads, request isolation, or multiplexing.

WSAPI's main influence is Ruby's [Rack](http://rack.rubyforge.org/) framework, but it was
also influenced by Python's [WSGI](http://wsgi.org/wsgi) (PEP 333). It's not a direct
clone of either of them, though, and tries to follow standard Lua idioms.

## Status

This is the first public release of WSAPI, version 1.0.

## Download

Get WSAPI using [LuaRocks](http://luarocks.org), with `luarocks install wsapi`.

## History

As this is the first release there is no history of previous releases.

## Credits

WSAPI was designed and developed by Fabio Mascarenhas and André Carregal,
and is maintained by Fabio Mascarenhas.

## Contact Us

For more information please [contact us](mailto:info-NO-SPAM-THANKS@keplerproject.org).
Comments are welcome!

You can also reach us and other developers and users on the Kepler Project 
[mailing list](http://luaforge.net/mail/?group_id=104). 

