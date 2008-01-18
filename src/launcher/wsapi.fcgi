#!/usr/bin/lua

-- Generic WSAPI FastCGI launcher, extracts application to launch
-- from SCRIPT_FILENAME/PATH_TRANSLATED, each application (defined
-- by its script entry point) gets an isolated Lua VM; sequential
-- requests to the same application go to the same VM

pcall(require,"luarocks.require")
local lfs = require "lfs"
local common = require "wsapi.common"
require "wsapi.fastcgi"
require "wsapi.ringer"

local app_states = {}

setmetatable(app_states, { __mode = "v" })

local start_path = lfs.currentdir()

local function app_loader(wsapi_env)
  lfs.chdir(start_path)
  local path, file, modname, ext, mtime = 
    common.find_module(nil, wsapi_env)
  lfs.chdir(path)
  local ringer
  local app_state = app_states[filename]
  if app_state and (app_state.mtime == mtime) then
    ringer = app_state.state
  else
    local bootstrap = [[
      pcall(require, "luarocks.require")
      _, package.path = remotedostring("return package.path")
      _, package.cpath = remotedostring("return package.cpath")
    ]]
    ringer = wsapi.ringer.new(modname, bootstrap)
    app_states[filename] = { state = ringer, mtime = mtime }
  end
  return ringer(wsapi_env)
end 

wsapi.fastcgi.run(app_loader)
