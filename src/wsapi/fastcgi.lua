-----------------------------------------------------------------------------
-- Fastcgi WSAPI handler
--
-- Author: Fabio Mascarenhas
-- Copyright (c) 2007 Kepler Project
--
-----------------------------------------------------------------------------

local fcgi = require"lfcgi"
local os = require"os"
local io = require"io"

module(..., package.seeall)

local function servervariable(env, n)
  local v = lfcgi.getenv (n) or os.getenv (n)
  env[n] = v or ""
  return v or ""
end

function run(app_run)
   while lfcgi.accept() >= 0 do
      local wsapi_env = {} 

      io.stdout = lfcgi.stdout
      io.stderr = lfcgi.stderr
      io.stdin = lfcgi.stdin

      wsapi_env.input = { bytes_read = 0 }

      function wsapi_env.input:read(n)
	 local n = n or self.size - self.bytes_read
	 if self.bytes_read < self.size then
            n = math.min(n, self.size - self.bytes_read)
            self.bytes_read = self.bytes_read + n
            return io.stdin:read(n)
	 end
      end

      wsapi_env.error = io.stderr

      setmetatable(wsapi_env, { __index =  servervariable })

      wsapi_env.input.size = tonumber(wsapi_env.CONTENT_LENGTH) or 0

      if wsapi_env.PATH_INFO == "" then wsapi_env.PATH_INFO = "/" end

      local ok, status, headers, res_iter = pcall(app_run, wsapi_env)
      if ok then
	 lfcgi.stdout:write("Status: " .. (status or 500) .. "\r\n")
	 for h, v in pairs(headers or {}) do
            if type(v) ~= "table" then
	       lfcgi.stdout:write(h .. ": " .. tostring(v) .. "\r\n") 
            else
	       for _, v in ipairs(v) do
		  lfcgi.stdout:write(h .. ": " .. tostring(v) .. "\r\n")
	       end
            end 
	 end
	 lfcgi.stdout:write("\r\n")
	 local ok, res = pcall(res_iter)
	 while ok and res do
	    lfcgi.stdout:write(res)
	    ok, res = pcall(res_iter)
	 end
	 if not ok then
	    lfcgi.stdout:write("======== WSAPI ERROR DURING RESPONSE PROCESSING: " ..
			    tostring(res))
	 end
      else
	 lfcgi.stderr:write("WSAPI error in application: " .. tostring(status) .. "\n")
	 lfcgi.stdout:write("Status: 500 Internal Server Error\r\n")
	 lfcgi.stdout:write("Content-type: text/plain\r\n\r\n")
	 lfcgi.stdout:write("WSAPI error in application: " .. tostring(status) .. "\n")
      end
   end
end

