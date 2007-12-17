-- Rings application for WSAPI

require "rings"

module("wsapi.ringer", package.seeall)

local function arg(n)
  return "select(" .. tostring(n) .. ",...)"
end

local init = [==[
  local wsapi_env = {}
  wsapi_env.error = {
    write = function (self, err)
      remotedostring("env.error:write(arg(1))", err)
    end
  }
  wsapi_env.input = {
    read = function (self, n)
      return coroutine.yield("RECEIVE", n)
    end
  }
  setmetatable(wsapi_env, { 
    __index = function (tab, k)
      local  _, v = remotedostring("return env[arg(1)]", k)
      rawset(tab, k, v)
      return v
    end,
    __newindex = function (tab, k, v)
      remotedostring("env[arg(1)] = arg(2)", k, v)
      rawset(tab, k, v)
    end })
  if arg(2) then
    local bootstrap, err
    if string.match(arg(2), "%w%.lua$") then
      bootstrap, err = loadfile(arg(2))
    else
      bootstrap, err = loadstring(arg(2))
    end
    if bootstrap then
      bootstrap()
    else
      error("could not load " .. arg(2) .. ": " .. err)
    end
  else
    _, package.path = remotedostring("return package.path")
    _, package.cpath = remotedostring("return package.cpath")
  end
  require"coxpcall"
  pcall = copcall
  xpcall = coxpcall
  local app = require(arg(1))
  main_coro = coroutine.wrap(function ()
      local status, headers, res = app.run(wsapi_env)
      remotedostring("status = arg(1)", status)
      for k, v in pairs(headers) do
        remotedostring("headers[arg(1)] = arg(2)", k, v)
      end
      local s = res()
      while s do
        coroutine.yield("SEND", s)
        s = res()
      end
    end)
]==]

init = string.gsub(init, "arg%((%d+)%)", arg)

function run(wsapi_env)
  local data = { status = 500, headers = {}, env = wsapi_env }
  setmetatable(data, { __index = _G })
  local new_state = rings.new(data)
  assert(new_state:dostring(init, RINGER_APP, RINGER_BOOTSTRAP))
  local ok, flag, s, v = new_state:dostring("return main_coro()")
  repeat
    if not ok then error(flag) end
    if flag == "RECEIVE" then
      ok, flag, s, v = new_state:dostring("return main_coro(...)",
        wsapi_env.input:read(s))
    elseif flag == "SEND" then
      break
    else
      error("Invalid command: " .. tostring(flag))
    end
  until flag == "SEND"
  local res = function ()
      if s then 
        local res = s
        s = nil
        return res
      end
      local ok, flag, s, v = new_state:dostring("return main_coro()")
      while ok and flag and s do
        if flag == "RECEIVE" then
          ok, flag, s, v = new_state:dostring("return main_coro(...)",
            wsapi_env.input:read(s))
        elseif flag == "SEND" then
          return s
        else
          error("Invalid command: " .. tostring(flag))
        end
      end
      if not ok then error(s) end
    end
  return data.status, data.headers, res 
end
