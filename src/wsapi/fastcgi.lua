-----------------------------------------------------------------------------
-- Fastcgi WSAPI handler
--
-- Author: Fabio Mascarenhas
-- Copyright (c) 2007 Kepler Project
--
-----------------------------------------------------------------------------

local lfcgi = require"lfcgi"
local os = require"os"
local io = require"io"
local common = require"wsapi.common"

module(...)

io.stdout = lfcgi.stdout
io.stderr = lfcgi.stderr
io.stdin = lfcgi.stdin

local getenv = function (n)
		  return lfcgi.getenv (n) or 
		     os.getenv (n)
	       end

function run(app_run)
   while lfcgi.accept() >= 0 do
      common.run(app_run, { input = lfcgi.stdin, output = lfcgi.stdout,
		    error = lfcgi.stderr, env = getenv })
   end
end
