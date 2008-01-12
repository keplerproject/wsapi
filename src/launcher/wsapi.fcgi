#!/usr/bin/lua

pcall(require,"luarocks.require")
require "lfs"
require "wsapi.fastcgi"

local filename = (...)

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

local function require_file(filename)
  local mode, err = lfs.attributes(filename, "mode")
  if not mode then error({ type = 404, message = err }) end
  local path, file
  if mode == "directory" then
    path, file = filename, "init.lua"
  else
    path, file = splitpath(filename)
  end
  lfs.chdir(path)
  local size, err = lfs.attributes(file, "size")
  if not size then error({ type = 404, message = err }) end
  local modname = splitext(file)
  if not package.loaded[modname] then
    local loader, err = loadfile(file)
    if loader == nil then
      error("unable to load file " .. file .. ", error: " .. err)
    end
    package.loaded[modname] = true
    local res = loader(modname)
    if res ~= nil then
      package.loaded[modname] = res
    end
  end
  return package.loaded[modname]
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
        <p>%s</p>
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
        <p>%s</p>
        </body>
        </html>
      ]], tostring(message)))
    end
    return 500, { ["Content-Type"] = "text/html" }, coroutine.wrap(res)
  end
end

local function get_runner(mod)
  if type(mod) == "table" then
    return mod.run
  else
    return mod
  end
end

local function app_loader(wsapi_env)
  local filename = wsapi_env.SCRIPT_FILENAME
  if filename == "" then filename = wsapi_env.PATH_TRANSLATED end
  if filename == "" then
    return send500("The server didn't provide a filename")(wsapi_env)
  end
  local ok, mod = pcall(require_file, filename)
  if mod then
    return get_runner(mod)(wsapi_env)
  else
    if type(mod) == "table" then
      return send404(mod.message)(wsapi_env)
    else
      return send500(mod)(wsapi_env)
    end
  end
end 

if filename then
  local ok, mod = pcall(require_file, filename)
  if ok then
    wsapi.fastcgi.run(get_runner(mod))
  else
    if type(mod) == "table" then
      wsapi.fastcgi.run(send404(mod.message))
    else
      wsapi.fastcgi.run(send500(mod))
    end
  end
else
  wsapi.fastcgi.run(app_loader)
end
