---------------------------------------------------------------------
-- Main Lua script.
-- This script should be run by the executable.
-- $Id: sapi.lua,v 1.5 2007/12/14 13:23:10 mascarenhas Exp $
---------------------------------------------------------------------

require"wsapi.response" 

wsapi.sapi = {}

local sapi_error(msg)
  local first_err = [[
    <html>
      <head><title>CGILua Error</title></head>
      <body><p>There was an error in your application. The
      error message is:</p>
      <pre>
  ]]
  local last_err = [[
      </pre>
      </body>
    </html>
  ]]
  return coroutine.wrap(function ()
    coroutine.yield(first_err)
    coroutine.yield(tostring(msg))
    coroutine.yield(last_err)
  end)
end

function wsapi.sapi.run(wsapi_env)
  local res = wsapi.response.new()

  SAPI = {
    Info =  {
	_COPYRIGHT = "Copyright (C) 2007 Kepler Project",
	_DESCRIPTION = "WSAPI SAPI implementation",
	_VERSION = "WSAPI SAPI 1.0",
	ispersistent = false,
    },
    Request = {
    	servervariable = function (name) return wsapi_env[name] end,
	getpostdata = function (n) return wsapi_env.input:read(n) end
    },
    Response = {
	contenttype = function (header)
  	  res["Content-Type"] = header
	end,  
	errorlog = function (msg, errlevel)
	  wsapi_env.error:write (msg)
	end,
	header = function (header, value)
	  res[header] = value
	end,
	redirect = function (url)
	  res.status = 302
	  res.header["Location"] = url
        end,
	write = function (...)
	  res:write({...})
	end,
    },
  }
  require"cgilua"
  local ok, err = cgilua.main()
  if not ok then
    return 200, { ["Content-Type"] = "text-html" }, sapi_error(err)
  else
    return res:finish()
  end
end

return wsapi.sapi

