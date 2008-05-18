-----------------------------------------------------------------------------
-- wsapi.common - common functionality for adapters and launchers
--
-- Author: Fabio Mascarenhas
-- Copyright (c) 2007 Kepler Project
--
-----------------------------------------------------------------------------

local lfs = require "lfs"
local _, ringer = pcall(require, "wsapi.ringer")
local _G = _G

pcall(lfs.setmode, io.stdin, "binary")
pcall(lfs.setmode, io.stdout, "binary")

module("wsapi.common", package.seeall)

-- Meta information is public even if begining with an "_"
_G.wsapi._COPYRIGHT   = "Copyright (C) 2007 Kepler Project"
_G.wsapi._DESCRIPTION = "WSAPI - the Lua Web Server API"
_G.wsapi._VERSION     = "WSAPI 1.0"

function sv_index(func)
   return function (env, n)
	     local v = func(n)
	     env[n] = v or ""
	     return v or ""
	  end
end

function input_maker(obj, read_method)
   local input = {}
   read = obj[read_method or "read"]

   function input:read(n)
     n = n or self.length or 0
     if n > 0 then return read(obj, n) end
   end
   return input
end

function normalize_app(app_run, is_file)
   local t = type(app_run)
   if t == "function" then
      return app_run
   elseif t == "table" then
      return app_run.run
   elseif t == "string" then
      if is_file then
	 return normalize_app(dofile(app_run))
      else
	 return normalize_app(require(app_run))
      end
   end
end

function send_content(out, res_iter, write_method)
   local write = out[write_method or "write"]
   local ok, res = xpcall(res_iter, debug.traceback)
   while ok and res do
      write(out, res)
      ok, res = xpcall(res_iter, debug.traceback)
   end
   if not ok then
      write(out, 
	    "======== WSAPI ERROR DURING RESPONSE PROCESSING: \n<pre>" ..
	      tostring(res) .. "\n</pre>")
   end
end

function send_output(out, status, headers, res_iter, write_method)
   local write = out[write_method or "write"]
   write(out, "Status: " .. (status or 500) .. "\r\n")
   for h, v in pairs(headers or {}) do
      if type(v) ~= "table" then
	 write(out, h .. ": " .. tostring(v) .. "\r\n") 
      else
	 for _, v in ipairs(v) do
	    write(out, h .. ": " .. tostring(v) .. "\r\n")
	 end
      end 
   end
   write(out, "\r\n")
   send_content(out, res_iter)
end

function error_html(msg)
   return string.format([[
        <html>
        <head><title>WSAPI Error in Application</title></head>
        <body>
        <p>There was an error in the specified application.
        The full error message follows:</p>
<pre>
%s
</pre>
        </body>
        </html>
      ]], tostring(msg))
end

function status_500_html(msg)
   return error_html(msg)
end

function status_404_html(msg)
   return string.format([[
        <html>
        <head><title>Resource not found</title></head>
        <body>
        <p>%s</p>
        </body>
        </html>
      ]], tostring(msg))
end

function status_200_html(msg)
   return string.format([[
        <html>
        <head><title>Resource not found</title></head>
        <body>
        <p>%s</p>
        </body>
        </html>
      ]], tostring(msg))
end

function send_error(out, err, msg, out_method, err_method)
   local write = out[out_method or "write"]
   local write_err = err[err_method or "write"]
   write_err(err, "WSAPI error in application: " .. tostring(msg) .. "\n")
   write(out, "Status: 500 Internal Server Error\r\n")
   write(out, "Content-type: text/html\r\n\r\n")
   write(out, error_html(msg))
end

function send_404(out, msg, out_method)
   local write = out[out_method or "write"]
   write(out, "Status: 404 Not Found\r\n")
   write(out, "Content-type: text/html\r\n\r\n")
   write(out, status_404_html(msg))
end

function run_app(app, env)
   return xpcall(function () return (normalize_app(app))(env) end,
		 function (msg)
		    if type(msg) == "table" then
		       env.STATUS = msg[1]
		       return _M["status_" .. msg[1] .. "_html"](msg[2]) 
		    else
		       return debug.traceback(msg, 2)
		    end
		 end)
end

function wsapi_env(t)
   local env = {}
   setmetatable(env, { __index = sv_index(t.env) })
   env.input = input_maker(t.input, t.read_method)
   env.error = t.error
   env.input.length = tonumber(env.CONTENT_LENGTH) or 0
   if env.PATH_INFO == "" then env.PATH_INFO = "/" end
   return env
end

function run(app, t)
   local env = wsapi_env(t) 
   local ok, status, headers, res_iter = 
      run_app(app, env)
   if ok then
      send_output(t.output, status, headers, res_iter)
   else
      if env.STATUS == 404 then
	 send_404(t.output, status)
      else
	 send_error(t.output, t.error, status)
      end
   end
end

function splitpath(filename)
  local path, file = string.match(filename, "^(.*)[/\\]([^/\\]*)$")
  return path, file
end

function splitext(filename)
  local modname, ext = string.match(filename, "^(.+)%.([^%.]+)$")
  if not modname then modname, ext = filename, "" end
  return modname, ext
end

function find_file(filename)
   local mode = assert(lfs.attributes(filename, "mode"))
   local path, file, modname, ext
   if mode == "directory" then
      path, modname = splitpath(filename)
      path = path .. "/" .. modname
      file = modname .. ".lua"
      ext = "lua"
   elseif mode == "file" then
      path, file = splitpath(filename)
      modname, ext = splitext(file)
   else
      return nil
   end
   local mtime = assert(lfs.attributes(path .. "/" .. file, "modification"))
   return path, file, modname, ext, mtime
end

function adjust_iis_path(wsapi_env, filename)
   local script_name, ext = 
      wsapi_env.SCRIPT_NAME:match("([^/%.]+)%.([^%.]+)$")
   if script_name then
      local path = 
	 filename:match("^(.+)" .. script_name .. "%." .. ext .. "[/\\]")
      if path then 
	 return path .. script_name .. "." .. ext 
      else 
	 return filename 
      end
   else
      return filename
   end
end

local function not_compatible(wsapi_env, filename)
  local script_name = wsapi_env.SCRIPT_NAME
  if not filename:gsub("\\","/"):find(script_name, 1, true) then
    -- more IIS madness, down into the rabbit hole...
    local path_info = wsapi_env.PATH_INFO:gsub("/", "\\")
    wsapi_env.DOCUMENT_ROOT = filename:sub(1, #filename-#path_info)
    return true
  end
end

function adjust_non_wrapped(wsapi_env, filename, launcher)
  if filename == "" or not_compatible(wsapi_env, filename) or 
    (launcher and filename:match(launcher:gsub("%.", "%.") .. "$")) then
    local path_info = wsapi_env.PATH_INFO
    local docroot = wsapi_env.DOCUMENT_ROOT
    if docroot:sub(#docroot) ~= "/" and docroot:sub(#docroot) ~= "\\" then
      docroot = docroot .. "/"
    end
    local s, e = path_info:find("[^/%.]+%.[^/%.]+", 1)
    while s do
      local filepath = path_info:sub(2, e)
	local filename
	if docroot:find("\\", 1, true) then
        filename = docroot .. filepath:gsub("/","\\")
      else
        filename = docroot .. filepath
      end
      local mode = lfs.attributes(filename, "mode")
      if not mode then
	error({ 404, "Resource " .. wsapi_env.SCRIPT_NAME .. "/" .. filepath
		 .. " not found!" }, 0)
      elseif lfs.attributes(filename, "mode") == "file" then
	wsapi_env.PATH_INFO = path_info:sub(e + 1)
	if wsapi_env.PATH_INFO == "" then wsapi_env.PATH_INFO = "/" end    
	wsapi_env.SCRIPT_NAME = wsapi_env.SCRIPT_NAME .. "/" .. filepath
	return filename
      end
      s, e = path_info:find("[^/%.]+%.[^/%.]+", e + 1)
    end
    error("could not find a filename to load, check your configuration or URL")
  else return filename end
end

function normalize_paths(wsapi_env, filename, launcher)
   if not filename then
     filename = wsapi_env.SCRIPT_FILENAME
     if filename == "" then filename = wsapi_env.PATH_TRANSLATED end
     filename = adjust_non_wrapped(wsapi_env, filename, launcher)
     filename = adjust_iis_path(wsapi_env, filename)
     wsapi_env.PATH_TRANSLATED = filename
     wsapi_env.SCRIPT_FILENAME = filename
   else
     if wsapi_env.PATH_TRANSLATED == "" then
       wsapi_env.PATH_TRANSLATED = wsapi_env.SCRIPT_FILENAME
     end
     if wsapi_env.SCRIPT_FILENAME == "" then
       wsapi_env.SCRIPT_FILENAME = wsapi_env.PATH_TRANSLATED
     end
     if wsapi_env.PATH_TRANSLATED == "" then
       wsapi_env.PATH_TRANSLATED = filename
       wsapi_env.SCRIPT_FILENAME = filename
     end
   end
   local s, e = wsapi_env.PATH_INFO:find(wsapi_env.SCRIPT_NAME, 1, true)
   if s == 1 then
     wsapi_env.PATH_INFO = wsapi_env.PATH_INFO:sub(e+1)
     if wsapi_env.PATH_INFO == "" then wsapi_env.PATH_INFO = "/" end    
   end
end

function find_module(wsapi_env, filename, launcher)
   normalize_paths(wsapi_env, filename, launcher)
   return find_file(wsapi_env.PATH_TRANSLATED)
end

function require_file(filename, modname)
  if not package.loaded[modname] then
    package.loaded[modname] = true
    local res = loadfile(filename)(modname)
    if res then
      package.loaded[modname] = res
    end
    return package.loaded[modname]
  end
end

function load_wsapi(path, file, modname, ext)
  lfs.chdir(path)
  local app
  if ext == "lua" then
    app = require_file(file, modname)
  else
    app = dofile(file)
  end
  return normalize_app(app)
end

do
  local app_states = {}
  setmetatable(app_states, { __index = function (tab, app)
					  tab[app] = {}
					  return tab[app]
				       end })

  local function bootstrap_app(path, file, modname, ext)
     local bootstrap = [=[
	   _, package.path = remotedostring("return package.path")
	   _, package.cpath = remotedostring("return package.cpath")
	   pcall(require, "luarocks.require")
	   wsapi = {}
	   wsapi.app_path = [[]=] .. path .. [=[]]
     ]=]
     if ext == "lua" then
	return ringer.new(modname, bootstrap)
     else
	return ringer.new(file, bootstrap, true)
     end
  end

  function load_wsapi_isolated(path, file, modname, ext, mtime)
    local filename = path .. "/" .. file
    lfs.chdir(path)
    local app, data
    local app_state = app_states[filename]
    if mtime and app_state.mtime == mtime then
      for _, state in ipairs(app_state.states) do
	 if not rawget(state.data, "status") then
	    return state.app
	 end
      end
      app, data = bootstrap_app(path, file, modname, ext)
      table.insert(app_state.states, { app = app, data = data })
    else
      app, data = bootstrap_app(path, file, modname, ext)
      if mtime then
	app_states[filename] = { states = { { app = app, data = data } }, 
				 mtime = mtime }
      end
    end
    return app
  end

end

function wsapi_loader_isolated_helper(wsapi_env, reload)
   local path, file, modname, ext, mtime = 
      find_module(wsapi_env)
   if reload then mtime = nil end
   if not path then
      error({ 404, "Resource " .. wsapi_env.SCRIPT_NAME .. " not found"})
   end
   local app = load_wsapi_isolated(path, file, modname, ext, mtime)
   wsapi_env.APP_PATH = path
   return app(wsapi_env)
end

function wsapi_loader_isolated(wsapi_env)
   return wsapi_loader_isolated_helper(wsapi_env)
end 

function wsapi_loader_isolated_reload(wsapi_env)
   return wsapi_loader_isolated_helper(wsapi_env, true)
end 

do
  local app_states = {}
  setmetatable(app_states, { __index = function (tab, app)
					  tab[app] = {}
					  return tab[app]
				       end })

  local function bootstrap_app(path, app_modname, extra)
     local bootstrap = [=[
	   _, package.path = remotedostring("return package.path")
	   _, package.cpath = remotedostring("return package.cpath")
	   pcall(require, "luarocks.require")
	   wsapi = {}
	   wsapi.app_path = [[]=] .. path .. [=[]]
     ]=] .. (extra or "")
     return ringer.new(app_modname, bootstrap)
  end

  function load_isolated_launcher(filename, app_modname, bootstrap)
    local app, data
    local app_state = app_states[filename]
    local path, _ = splitpath(filename)
    local mtime = lfs.attributes(filename, "modification")
    if app_state.mtime == mtime then
      for _, state in ipairs(app_state.states) do
	 if not rawget(state.data, "status") then
	    return state.app
	 end
      end
      app, data = bootstrap_app(path, app_modname, bootstrap)
      table.insert(app_state.states, { app = app, data = data })
   else
      app, data = bootstrap_app(path, app_modname, bootstrap)
      app_states[filename] = { states = { { app = app, data = data } }, 
	 mtime = mtime }
    end
    return app
  end

end
