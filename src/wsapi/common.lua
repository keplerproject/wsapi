-----------------------------------------------------------------------------
-- wsapi.common - common functionality for adapters and launchers
--
-- Author: Fabio Mascarenhas
-- Copyright (c) 2007 Kepler Project
--
-----------------------------------------------------------------------------

local lfs = require "lfs"
local ringer = require "wsapi.ringer"

module(..., package.seeall)

function sv_index(func)
   return function (env, n)
	     local v = func(n)
	     env[n] = v or ""
	     return v or ""
	  end
end

function input_maker(obj, read_method)
   local input = { bytes_read = 0 }

   function input:read(n)
      local n = n or self.size - self.bytes_read
      if self.bytes_read < self.size then
	 n = math.min(n, self.size - self.bytes_read)
	 self.bytes_read = self.bytes_read + n
	 return obj[read_method or "read"](obj, n)
      end
   end
   return input
end

function norm_app(app_run)
   local t = type(app_run)
   if t == "function" then
      return app_run
   elseif t == "table" then
      return app_run.run
   elseif t == "string" then
      return norm_app(require(app_run))
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
	    "======== WSAPI ERROR DURING RESPONSE PROCESSING: " ..
	      tostring(res))
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

function send_error(out, err, msg, out_method, err_method)
   local write = out[out_method or "write"]
   local write_err = err[err_method or "write"]
   write_err(err, "WSAPI error in application: " .. tostring(msg) .. "\n")
   write(out, "Status: 500 Internal Server Error\r\n")
   write(out, "Content-type: text/html\r\n\r\n")
   write(out, string.format([[
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
      ]], tostring(msg)))
end

function run_app(app, env)
   return xpcall(function () return (norm_app(app))(env) end,
		 debug.traceback)
end

function wsapi_env(t)
   local env = {}
   env.input = input_maker(t.input, t.read_method)
   env.error = t.error
   setmetatable(env, { __index = sv_index(t.env) })
   env.input.size = tonumber(env.CONTENT_LENGTH) or 0
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
      send_error(t.output, t.error, status)
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
   else
      path, file = splitpath(filename)
      modname, ext = splitext(file)
   end
   local mtime = assert(lfs.attributes(path .. "/" .. file, "modification"))
   return path, file, modname, ext, mtime
end

function adjust_iis_path(filename, wsapi_env)
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

function adjust_non_wrapped(filename, wsapi_env)
  if filename == "" or filename:match("%.exe$") then
    local path_info = wsapi_env.PATH_INFO
    local docroot = wsapi_env.DOCUMENT_ROOT
    local s, e = path_info:find("[^/%.]+%.[^/%.]+", 1)
    while s do
      local filepath = path_info:sub(1, e)
      local filename = docroot .. filepath
      if lfs.attributes(filename, "mode") == "file" then
	wsapi_env.PATH_INFO = path_info:sub(e + 1)
	if wsapi_env.PATH_INFO == "" then wsapi_env.PATH_INFO = "/" end    
	wsapi_env.SCRIPT_NAME = wsapi_env.SCRIPT_NAME .. filepath
	wsapi_env.PATH_TRANSLATED = filename
	wsapi_env.SCRIPT_FILENAME = filename
	return filename
      end
      s, e = path_info:find("[^/%.]+%.[^/%.]+", e + 1)
    end
    error("could not find a filename to load, check your URL")
  else return filename end
end

function find_module(filename, wsapi_env)
   if not filename then
     filename = wsapi_env.SCRIPT_FILENAME
     if filename == "" then filename = wsapi_env.PATH_TRANSLATED end
     filename = adjust_non_wrapped(filename, wsapi_env)
     filename = adjust_iis_path(filename, wsapi_env)
   end
   local path, file, modname, ext, mtime = find_file(filename)
   local s, e = wsapi_env.PATH_INFO:find(wsapi_env.SCRIPT_NAME, 1, true)
   if s == 1 then
     wsapi_env.PATH_INFO = wsapi_env.PATH_INFO:sub(e+1)
     if wsapi_env.PATH_INFO == "" then wsapi_env.PATH_INFO = "/" end    
   end
   return path, file, modname, ext, mtime
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
  return norm_app(app)
end

do
  local app_states = {}
  setmetatable(app_states, { __mode = "v" })

  function load_wsapi_isolated(path, file, modname, ext, mtime)
    local filename = path .. "/" .. file
    lfs.chdir(path)
    local app
    local app_state = app_states[filename]
    if app_state and (app_state.mtime == mtime) then
      app = app_state.state
    else
      local bootstrap = [[
	  pcall(require, "luarocks.require")
	  _, package.path = remotedostring("return package.path")
	  _, package.cpath = remotedostring("return package.cpath")
      ]]
      if ext == "lua" then
	app = ringer.new(modname, bootstrap)
      else
	app = ringer.new(file, bootstrap)
      end
      app_states[filename] = { state = app, mtime = mtime }
    end
    return app
  end
end

function wsapi_loader_isolated(wsapi_env)
  local path, file, modname, ext, mtime = 
      	      	    find_module(nil, wsapi_env)
  local app = load_wsapi_isolated(path, file, modname, ext, mtime)
  return app(wsapi_env)
end 
