-- Rings application for WSAPI

processes = processes or {}
pid = pid or 1

module("wsapi.ringer", package.seeall)

require "rings"

local function arg(n)
  return "select(" .. tostring(n) .. ",...)"
end

local init = [==[
  local id_string = 'processes[' .. arg(1) .. ']'
  local wsapi_env = {}
  wsapi_env.error = {
    write = function (self, err)
      remotedostring(id_string .. '.env.error:write(arg(1))', err)
    end
  }
  wsapi_env.input = {
    read = function (self, n)
      local _, s = remotedostring("return " .. id_string .. ".env.input:read(arg(1))", n)
      return s
    end
  }
  setmetatable(wsapi_env, { 
    __index = function (tab, k)
      local v = rawget(tab, k)
      if not v then
        _, v = remotedostring("return " .. id_string .. '.env[arg(1)]', k)
      end
      return v
    end,
    __newindex = function (tab, k, v)
      remotedostring(id_string .. '.env[arg(1)] = arg(2)', k, v)
    end })
  _, package.path = remotedostring("return package.path")
  _, package.cpath = remotedostring("return package.cpath")
  local app = require(arg(2))
  local status, headers, res = app.run(wsapi_env)
  remotedostring(id_string .. ".status = arg(1)", status)
  for k, v in pairs(headers) do
    remotedostring(id_string .. ".headers[arg(1)] = arg(2)", k, v)
  end
  main_coro = coroutine.wrap(function ()
      local s = res()
      while s do
        coroutine.yield(s)
        s = res()
      end
    end)
]==]

init = string.gsub(init, "arg%((%d+)%)", arg)

print(init)

function run(wsapi_env)
  local current_pid = pid
  pid = pid + 1
  processes[current_pid] = { env = wsapi_env, headers = {} }
  local new_state = rings.new()
  assert(new_state:dostring(init, current_pid, RINGER_APP))
  local res = coroutine.wrap(function ()
      local status, s 
      status, s = new_state:dostring("return main_coro()")
      while status and s do
        coroutine.yield(s)
        status, s = new_state:dostring("return main_coro()")
      end
      if not status then error(s) end
    end)
  return processes[current_pid].status, processes[current_pid].headers, res 
end
