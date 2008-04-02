
local orbit = require "orbit"
local cosmo = require "cosmo"

local io = io
local setmetatable, loadstring, setfenv = setmetatable, loadstring, setfenv
local error, tostring = error, tostring

module("wsapi.cosmo", orbit.new)

function handle_get(web)
  local env = {}
  setmetatable(env, { __index = _G })
  env.web = web
  function env.lua(arg)
    local f = loadstring(arg[1])
    setfenv(f, env)
    local res = f()
    return res or ""
  end
  function env.redirect(arg)
    web:redirect(arg[1])
    return ""
  end
  function env.include(arg)
    local file
    local name = arg[1]
    if name:sub(1, 1) == "/" then
      file = io.open(web.doc_root .. name)
    else
      file = io.open(web.real_path .. "/" .. name)
    end
    if not file then return "" end
    local template = file:read("*a")
    file:close()
    return cosmo.fill(template, env)
  end
  function env.model(arg)
    return _M:model(arg[1])
  end
  local file = io.open(web.path_translated)
  if not file then
    web.status = 404
    return [[<html>
	  <head><title>Not Found</title></head>
	  <body><p>Not found!</p></body></html>]]
  end
  local template = file:read("*a")
  return cosmo.fill(template, env)
end

handle_post = handle_get

return _M
