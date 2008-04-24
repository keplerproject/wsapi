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
local ipairs = ipairs

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
      local env_vars = lfcgi.environ()
      local env = {}
      for _, s in ipairs(env_vars) do
	 local name, val = s:match("^([^=]+)=(.*)$")
	 env[name] = val
      end
      common.run(app_run, { input = lfcgi.stdin, output = lfcgi.stdout,
			    error = lfcgi.stderr, env = env })
   end
end
