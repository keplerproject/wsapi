-----------------------------------------------------------------------------
-- Xavante WSAPI handler
--
-- Author: Fabio Mascarenhas
-- Copyright (c) 2007 Kepler Project
--
-----------------------------------------------------------------------------

require "coxpcall"

pcall = copcall
xpcall = coxpcall

local common = require"wsapi.common"

module (..., package.seeall)

-------------------------------------------------------------------------------
-- Implements WSAPI
-------------------------------------------------------------------------------

local function set_cgivars (req, diskpath, path_info_pat, script_name_pat)
   diskpath = diskpath or req.diskpath or ""
   req.cgivars = {
      SERVER_SOFTWARE = req.serversoftware,
      SERVER_NAME = req.parsed_url.host,
      GATEWAY_INTERFACE = "CGI/1.1",
      SERVER_PROTOCOL = "HTTP/1.1",
      SERVER_PORT = req.parsed_url.port,
      REQUEST_METHOD = req.cmd_mth,
      DOCUMENT_ROOT = diskpath,
      PATH_INFO = string.match(req.parsed_url.path, path_info_pat) or "",
      PATH_TRANSLATED = script_name_pat and (diskpath .. script_name_pat),
      SCRIPT_NAME = script_name_pat,
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

local function wsapihandler (req, res, wsapi_run, app_prefix, docroot, app_path)
   local path_info_pat = "^" .. (app_prefix or "") .. "(.*)"
   set_cgivars(req, docroot, path_info_pat, app_prefix)

   local get_cgi_var = function (var) 
			  return req.cgivars[var] or ""
		       end

   local wsapi_env = common.wsapi_env{ input = req.socket, 
				       read_method = "receive", error = io.stderr, 
				       env = get_cgi_var }
   wsapi_env.APP_PATH = app_path

   local function set_status(status)
      res.statusline = "HTTP/1.1 " .. tostring(status) 
   end

   local function send_headers(headers)
      for h, v in pairs(headers) do
	 if h == "Status" or h == "Content-Type" then
	    res.headers[h] = v
	 elseif type(v) == "string" then
	    res:add_header(h, v)
	 elseif type(v) == "table" then
	    for _, v in ipairs(v) do
	       res:add_header(h, tostring(v))
	    end
	 else
            res:add_header(h, tostring(v))
         end
      end
   end

   local ok, status, headers, res_iter = common.run_app(wsapi_run, wsapi_env)
   if ok then
      set_status(status or 500)
      send_headers(headers or {})
      common.send_content(res, res_iter, "send_data")
   else
      if wsapi_env.STATUS == 404 then
	 res.statusline = "HTTP/1.1 404" 
	 send_headers({ ["Content-Type"] = "text/html" })
	 res:send_data(status)
      else
	 res.statusline = "HTTP/1.1 500" 
	 send_headers({ ["Content-Type"] = "text/html" })
	 res:send_data(common.error_html(status))
      end
   end
end

-------------------------------------------------------------------------------
-- Returns the WSAPI handler
-------------------------------------------------------------------------------
function makeHandler (app_func, app_prefix, docroot, app_path)
   return function (req, res)
	     return wsapihandler(req, res, app_func, app_prefix, docroot, app_path)
	  end
end

function makeGenericHandler(docroot, reload)
  if reload then
    return function (req, res)
	     return wsapihandler(req, res, common.wsapi_loader_isolated_reload, nil, docroot)
	   end
  else
    return function (req, res)
	     return wsapihandler(req, res, common.wsapi_loader_isolated, nil, docroot)
	   end
  end
end
