-------------------------------------------------------------------------------
-- Sample Xavante configuration file for launching WSAPI applications.
------------------------------------------------------------------------------

require "xavante.filehandler"
require "wsapi.xavante"

-- Here you require your WSAPI/Orbit application
local wsapi_app = require"app"

-- Define here where Xavante HTTP documents scripts are located
local webDir = "/var/www"

local simplerules = {

    { -- WSAPI application will be mounted under /app
      match = { "^/app$", "^/app/" },
      with = wsapi.xavante.makeHandler(wsapi_app.run, "/app")
    },
    
    { -- filehandler 
      match = ".",
      with = xavante.filehandler,
      params = {baseDir = webDir}
    },
} 

-- Displays a message in the console with the used ports
xavante.start_message(function (ports)
    local date = os.date("[%Y-%m-%d %H:%M:%S]")
    print(string.format("%s Xavante started on port(s) %s",
      date, table.concat(ports, ", ")))
  end)

xavante.HTTP{
    server = {host = "*", port = 8080},
    
    defaultHost = {
    	rules = simplerules
    },
}
