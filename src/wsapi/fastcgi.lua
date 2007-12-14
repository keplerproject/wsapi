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

--      if wsapi_env.PATH_TRANSLATED == "" and
--        wsapi_env.SCRIPT_NAME == "" and
--         wsapi_env.SCRIPT_FILENAME ~= "" then 
--        wsapi_env.PATH_TRANSLATED = wsapi_env.SCRIPT_FILENAME
--        wsapi_env.SCRIPT_NAME = string.match(wsapi_env.SCRIPT_FILENAME,
--          "^" .. wsapi_env.DOCUMENT_ROOT .. "(.+)$")
--      end

      local ok, status, headers, res_iter = pcall(app_run, wsapi_env)
      if ok then
	 lfcgi.stdout:write("Status: " .. status .. "\r\n")
	 for h, v in pairs(headers) do
            if type(v) ~= "table" then
	       lfcgi.stdout:write(h .. ": " .. tostring(v) .. "\r\n") 
            else
	       for _, v in ipairs(v) do
		  lfcgi.stdout:write(h .. ": " .. tostring(v) .. "\r\n")
	       end
            end 
	 end
	 lfcgi.stdout:write("\r\n")
	 local res = res_iter()
	 while res do
            lfcgi.stdout:write(res)
            res = res_iter()
	 end
       else
	 io.stderr:write(status)
      end
   end
end

