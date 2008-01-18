-----------------------------------------------------------------------------
-- wsapi.common - common functionality for adapters and launchers
--
-- Author: Fabio Mascarenhas
-- Copyright (c) 2007 Kepler Project
--
-----------------------------------------------------------------------------

local lfs = require "lfs"

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
   write_method = write_method or "write"
   local ok, res = xpcall(res_iter, debug.traceback)
   while ok and res do
      out[write_method](out, res)
      ok, res = xpcall(res_iter, debug.traceback)
   end
   if not ok then
      out[write_method](out, 
			"======== WSAPI ERROR DURING RESPONSE PROCESSING: " ..
			   tostring(res))
   end
end

function send_output(out, status, headers, res_iter)
   out:write("Status: " .. (status or 500) .. "\r\n")
   for h, v in pairs(headers or {}) do
      if type(v) ~= "table" then
	 out:write(h .. ": " .. tostring(v) .. "\r\n") 
      else
	 for _, v in ipairs(v) do
	    out:write(h .. ": " .. tostring(v) .. "\r\n")
	 end
      end 
   end
   out:write("\r\n")
   send_content(out, res_iter)
end

function send_error(out, err, msg)
   err:write("WSAPI error in application: " .. tostring(msg) .. "\n")
   out:write("Status: 500 Internal Server Error\r\n")
   out:write("Content-type: text/html\r\n\r\n")
   out:write(string.format([[
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
  local path, file = string.match(filename, "^(.*[/\\])([^/\\]*)$")
  if not path then path, file = "", filename end
  local start_path, colon = string.sub(path, 1, 1), string.sub(path, 2, 2)
  if not (start_path == "/" or start_path == "." or 
	  colon == ":" or start_path == "\\") then
    path = "./" .. path
  end
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
      wsapi_env.SCRIPT_NAME:match("([^/\\%.]+)%.([^%.]+)$")
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

function find_module(filename, wsapi_env)
   filename = filename or wsapi_env.SCRIPT_FILENAME
   if filename == "" then filename = wsapi_env.PATH_TRANSLATED end
   if filename == "" then
      error("the server didn't provide a filename")
   end
   filename = adjust_iis_path(filename, wsapi_env)
   local path, file, modname, ext, mtime = find_file(filename)
   if wsapi_env.PATH_INFO:match(modname .. "%." .. ext) then
      wsapi_env.PATH_INFO = 
	 wsapi_env.PATH_INFO:match(modname .. "%." .. ext .. "(.*)$")
      if wsapi_env.PATH_INFO == "" then wsapi_env.PATH_INFO = "/" end    
   end
   return path, file, modname, ext, mtime
end

