---------------------------------------------------------------------
-- Main Lua script.
-- This script should be run by the executable.
-- $Id: sapi.lua,v 1.1.1.1 2007/10/30 23:44:46 mascarenhas Exp $
---------------------------------------------------------------------

-- Kepler bootstrap
local bootstrap, err = loadfile("kepler_init.lua") or loadfile(os.getenv("KEPLER_INIT") or "") or loadfile([[/etc/kepler/1.1/kepler_init.lua]])

if bootstrap then
  bootstrap()
end

require"wsapi.response" 

wsapi.sapi = {}

function wsapi.sapi.run(wsapi_env)
  wsapi_env.SCRIPT_NAME = wsapi_env.PATH_INFO
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
  	  res["Content-type"] = header
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
  res.status = tonumber(cgilua.main() or 200)
  return res:finish()
end
