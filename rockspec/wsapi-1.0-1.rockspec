package = "WSAPI"

version = "1.0-1"

description = {
  summary = "Lua Web Server API",
  detailed = [[
    WSAPI is an API that abstracts the web server from Lua web applications.
  ]],
  license = "MIT/X11",
  homepage = "http://www.keplerproject.org/wsapi"
}

dependencies = { }

source = {
  url = "cvs://:pserver:anonymous@cvs.luaforge.net:/cvsroot/wsapi",
  cvs_tag = "HEAD"
}

build = {
   type = "make",
   build_pass = true,
   install_target = "install-rocks",
   install_variables = {
     PREFIX  = "$(PREFIX)",
     LUA_BIN = "/usr/bin/env lua",
     LUA_DIR = "$(LUADIR)",
     BIN_DIR = "$(BINDIR)"
   },
   platforms = {
     unix = {
       build_pass = false,
       build_target = "all",
       build_variables = {
         LIB_OPTION = "$(LIBFLAG)",
         CFLAGS = "$(CFLAGS) -I$(LUA_INCDIR)",
       },
       install_target = "install-rocks-all",
       install_variables = {
         LUA_LIBDIR = "$(LIBDIR)"
       }
     },
     win32 = {
       type = "command",
       build_command = "nmake /f Makefile.win",
       install_command = "nmake /f Makefile.win PREFIX=$(PREFIX) install-rocks"
     }
   }
}
