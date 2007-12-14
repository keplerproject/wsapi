-----------------------------------------------------------------------------
-- Xavante WSAPI handler
--
-- Author: Fabio Mascarenhas
-- Copyright (c) 2007 Kepler Project
--
-----------------------------------------------------------------------------

module (..., package.seeall)

-------------------------------------------------------------------------------
-- Implements WSAPI
-------------------------------------------------------------------------------

local function set_cgivars (req, diskpath, path_info_pat, script_name_pat)
   req.cgivars = {
      SERVER_SOFTWARE = req.serversoftware,
      SERVER_NAME = req.parsed_url.host,
      GATEWAY_INTERFACE = "CGI/1.1",
      SERVER_PROTOCOL = "HTTP/1.1",
      SERVER_PORT = req.parsed_url.port,
      REQUEST_METHOD = req.cmd_mth,
      DOCUMENT_ROOT = req.diskpath,
      PATH_INFO = string.match(req.parsed_url.path, path_info_pat) or "",
      PATH_TRANSLATED = (req.diskpath or "") .. (string.match(req.parsed_url.path, script_name_pat) or ""),
      SCRIPT_NAME = string.match(req.parsed_url.path, script_name_pat),
      QUERY_STRING = req.parsed_url.query or "",
      REMOTE_ADDR = string.gsub (req.rawskt:getpeername (), ":%d*$", ""),
      CONTENT_TYPE = req.headers ["content-type"],
      CONTENT_LENGTH = req.headers ["content-length"],
   }
   if req.cgivars.PATH_INFO == "" then req.cgivars.PATH_INFO = "/" end
   for n,v in pairs (req.headers) do
      req.cgivars ["HTTP_"..string.gsub (string.upper (n), "-", "_")] = v
   end
end

local function wsapihandler (req, res, wsapi_run, app_prefix)
   local path_info_pat = "^" .. app_prefix .. "(.*)"
   local script_name_pat = "^(" .. app_prefix .. ")"

   set_cgivars(req, nil, path_info_pat, script_name_pat)

   local function get_cgi_var(env, var)
      local val = req.cgivars[var] or ""
      env[var] = val
      return val
   end

   local wsapi_env, input, error = {}, { bytes_read = 0 }, {}

   function error:write(s)
      io.stderr:write(s)
   end

   function input:read(n)
      local n = n or self.size - self.bytes_read
      if self.bytes_read < self.size then
	 n = math.min(n, self.size - self.bytes_read)
	 self.bytes_read = self.bytes_read + n
	 return req.socket:receive(n)
      end
   end

   setmetatable(wsapi_env, { __index = get_cgi_var })
   wsapi_env.input = input
   input.size = tonumber(wsapi_env.CONTENT_LENGTH) or 0
   wsapi_env.error = error

   local function set_status(status)
      res.statusline = "HTTP/1.1 " .. tostring(status) 
   end

   local function send_headers(headers)
      for h, v in pairs(headers) do
	 if h == "Status" or h == "Content-Type" then
	    res.headers[h] = v
	 elseif type(v) == "string" then
	    res:add_header(h, v)
	 else
	    for _, v in ipairs(v) do
	       res:add_header(h, v)
	    end
	 end
      end
   end

   local function send_content(res_iter)
      local s = res_iter()
      while s do
	 res:send_data(s)
	 s = res_iter()
      end
   end

   local status, headers, res_iter = wsapi_run(wsapi_env)
   set_status(status)
   send_headers(headers)
   send_content(res_iter)
end

-------------------------------------------------------------------------------
-- Returns the WSAPI handler
-------------------------------------------------------------------------------
function makeHandler (app_func, app_prefix)
   return function (req, res)
	     return wsapihandler(req, res, app_func, app_prefix or "")
	  end
end
