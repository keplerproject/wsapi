#!/usr/bin/lua

pcall(require,"luarocks.require")
require "lfs"
require "wsapi.fastcgi"
require "wsapi.ringer"

local arg_filename = (...)

local function splitpath(filename)
  local path, file = string.match(filename, "^(.*/)([^/]*)$")
  if not path then path, file = "", filename end
  local start_path = string.sub(path, 1, 1)
  if not (start_path == "/" or start_path == ".") then
    path = "./" .. path
  end
  return path, file
end

local function splitext(filename)
  local modname, ext = string.match(filename, "^(.+)(%.[^%.]+)$")
  if not modname then modname, ext = filename, "" end
  return modname, ext
end

local function find_file(filename)
  local mode, err = lfs.attributes(filename, "mode")
  if not mode then error({ type = 404, message = err }) end
  local path, file, modname
  if mode == "directory" then
    path, modname = splitpath(filename)
    path = path .. "/" .. modname
    file = modname .. ".lua"
  else
    path, file = splitpath(filename)
    modname = splitext(file)
  end
  local mtime, err = lfs.attributes(path .. "/" .. file, "modification")
  if not mtime then error({ type = 404, message = err }) end
  return path, file, modname, mtime
end

function send404(message)
  return function (wsapi_env)
    local function res()
      coroutine.yield(string.format([[
        <html>
        <head><title>Resource not Found</title></head>
        <body>
        <p>The specified resource could not be found on the server.
        The full error message follows:</p>
<pre>
%s
</pre>
        </body>
        </html>
      ]], tostring(message)))
    end
    return 404, { ["Content-Type"] = "text/html" }, coroutine.wrap(res)
  end
end

function send500(message)
  return function (wsapi_env)
    local function res()
      coroutine.yield(string.format([[
        <html>
        <head><title>Error in Application</title></head>
        <body>
        <p>There was an error in the specified application.
        The full error message follows:</p>
<pre>
%s
</pre>
        </body>
        </html>
      ]], tostring(message)))
    end
    return 500, { ["Content-Type"] = "text/html" }, coroutine.wrap(res)
  end
end

local app_states = {}

setmetatable(app_states, { __mode = "v" })

local function app_loader(wsapi_env)
  local filename = arg_filename or wsapi_env.SCRIPT_FILENAME
  if filename == "" then filename = wsapi_env.PATH_TRANSLATED end
  if filename == "" then
    return send500("The server didn't provide a filename")(wsapi_env)
  end
  local ok, path, file, modname, mtime = pcall(find_file, filename)
  if not ok then
    if type(path) == table then
        return send404(path.message)(wsapi_env)
    else
        return send500(path)(wsapi_env)
    end
  end
  local app_state = app_states[filename]
  if app_state and (app_state.mtime == mtime) then
    wsapi.ringer.RINGER_STATE = app_state.state
    wsapi.ringer.RINGER_DATA = app_state.data
    local ok, status, headers, res = pcall(wsapi.ringer.run, wsapi_env)
    if not ok then
      return send500(status)(wsapi_env)
    else
      return status, headers, res
    end
  else
    wsapi.ringer.RINGER_STATE = nil
    wsapi.ringer.RINGER_DATA = nil
    wsapi.ringer.RINGER_APP = modname
    wsapi.ringer.RINGER_BOOTSTRAP = [[
      pcall(require, "luarocks.require")
      _, package.path = remotedostring("return package.path")
      _, package.cpath = remotedostring("return package.cpath")
      require"lfs"
      lfs.chdir(]] .. string.format("%q", path) .. [[)
    ]]
    local ok, status, headers, res = pcall(wsapi.ringer.run, wsapi_env)
    if not ok then
      return send500(status)(wsapi_env)
    else
      app_states[filename] = { state = wsapi.ringer.RINGER_STATE,
        data = wsapi.ringer.RINGER_DATA, mtime = mtime }
      return status, headers, res
    end
  end
end 

wsapi.fastcgi.run(app_loader)

