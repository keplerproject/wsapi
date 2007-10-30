-----------------------------------------------------------------------------
-- CGI WSAPI handler
--
-- Author: Fabio Mascarenhas
-- Copyright (c) 2007 Kepler Project
--
-----------------------------------------------------------------------------

local os = require"os"
local io = require"io"

module(..., package.seeall)

local function servervariable(env, n)
  local v = os.getenv(n)
  env[n] = v or ""
  return v or ""
end

function run(app_run)

   local wsapi_env = {} 

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
     io.stdout:write("Status: " .. status .. "\r\n")
     for h, v in pairs(headers) do
       if type(v) ~= "table" then
         io.stdout:write(h .. ": " .. tostring(v) .. "\r\n") 
       else
         for _, v in ipairs(v) do
           io.stdout:write(h .. ": " .. v .. "\r\n")
         end
       end 
     end
     io.stdout:write("\r\n")
     local res = res_iter()
     while res do
       io.stdout:write(res)
       res = res_iter()
     end
   else
     io.stderr:write(status)
   end
end

