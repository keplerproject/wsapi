#!/usr/bin/lua

-- Generic WSAPI CGI launcher, extracts application to launch
-- either from the command line (use #!wsapi in the script)
-- or from SCRIPT_FILENAME/PATH_TRANSLATED

pcall(require, "luarocks.require")

local common = require "wsapi.common"
local cgi = require "wsapi.cgi"

local arg_filename = (...)

local function wsapi_loader(wsapi_env)
  local path, file, modname, ext = 
  	common.find_module(wsapi_env, arg_filename, "wsapi.cgi")
  local app = common.load_wsapi(path, file, modname, ext)
  return app(wsapi_env)
end 

cgi.run(wsapi_loader)
