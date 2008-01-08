package = "WSAPI-FCGI"

version = "1.0-1"

description = {
  summary = "Lua Web Server API FastCGI Adapter",
  detailed = [[
    WSAPI is an API that abstracts the web server from Lua web applications. This
    is the rock that contains the FCGI module used by wsapi.fcgi (only for Unix
    for now).
  ]],
  license = "MIT/X11",
  homepage = "http://www.keplerproject.org/wsapi"
}

dependencies = { 'wsapi' }

external_dependencies = {
  platforms = {
    unix = {
      FASTCGI = {
        header = "fcgi_stdio.h"
      }
    }
  }
}

source = {
  url = "cvs://:pserver:anonymous@cvs.luaforge.net:/cvsroot/wsapi",
  cvs_tag = "HEAD"
}

build = {
   platforms = {
     unix = {
        type = "make",
   	install_target = "install-fcgi",
   	install_variables = {
     	  PREFIX  = "$(PREFIX)",
   	  LUA_BIN = "/usr/bin/env lua",
     	  LUA_DIR = "$(LUADIR)",
     	  BIN_DIR = "$(BINDIR)"
   	},
       	build_pass = true,
       	build_target = "fcgi",
       	build_variables = {
         LIB_OPTION = "$(LIBFLAG) -L$(FASTCGI_LIBDIR)",
         CFLAGS = "$(CFLAGS) -I$(LUA_INCDIR) -I$(FASTCGI_INCDIR)",
       	},
       	install_variables = {
         LUA_LIBDIR = "$(LIBDIR)"
       	}
     }
  }
}
