
local orbit = require "orbit"
local cosmo = require "cosmo"

local io, string = io, string
local setmetatable, loadstring, setfenv = setmetatable, loadstring, setfenv
local error, tostring = error, tostring
local print = print

module("wsapi.cosmo", orbit.new)

local template_cache = {}

local function remove_shebang(s)
  return s:gsub("^#![^\n]+", "")
end

local function splitpath(filename)
  local path, file = string.match(filename, "^(.*)[/\\]([^/\\]*)$")
  return path, file
end

local function load_template(filename)
  local template = template_cache[filename]
  if not template then
     local file = io.open(filename)
     if not file then
	return nil
     end
     template = cosmo.compile(remove_shebang(file:read("*a")))
     template_cache[filename] = template
     file:close()
  end
  return template
end

function handle_get(web)
  local env = setmetatable({}, { __index = _G })
  env.web = web
  local filename = web.path_translated
  web.real_path = splitpath(filename)
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
  function env.fill(arg)
    cosmo.yield(arg[1])
  end
  function env.include(arg)
    local filename
    local name = arg[1]
    if name:sub(1, 1) == "/" then
      filename = web.doc_root .. name
    else
      filename = web.real_path .. "/" .. name
    end
    local template = load_template(filename)
    if not template then return "" end
    local subt_env
    if arg[2] then
      subt_env = setmetatable(arg[2], { __index = env })
    else
      subt_env = env
    end
    return template(subt_env)
  end
  function env.model(arg)
    return _M:model(arg[1])
  end
  local template = load_template(filename)
  if template then
     return template(env)
  else
     web.status = 404
     return [[<html>
	      <head><title>Not Found</title></head>
	      <body><p>Not found!</p></body></html>]]
  end
end

handle_post = handle_get

return _M
