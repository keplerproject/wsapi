#!/usr/bin/lua

-- Generic WSAPI FastCGI launcher, extracts application to launch
-- from SCRIPT_FILENAME/PATH_TRANSLATED, each application (defined
-- by its script entry point) gets an isolated Lua VM; sequential
-- requests to the same application go to the same VM

pcall(require,"luarocks.require")

local common = require "wsapi.common"
local fastcgi = require "wsapi.fastcgi"

local function wsapi_loader(wsapi_env)
  local path, file, modname, ext, mtime = 
  	common.find_module(wsapi_env, nil, "wsapi.fcgi")
  local app = common.load_wsapi_isolated(path, file, modname, ext, mtime)
  wsapi_env.APP_PATH = path
  return app(wsapi_env)
end 

fastcgi.run(wsapi_loader)
