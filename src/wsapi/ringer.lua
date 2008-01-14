-- Rings application for WSAPI

require "rings"

module("wsapi.ringer", package.seeall)

local function arg(n)
  return "select(" .. tostring(n) .. ",...)"
end

local init = [==[
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
  require"wsapi.coxpcall"
  pcall = copcall
  xpcall = coxpcall
  local app = require(arg(1))
  if type(app) == "table" then
    app = app.run
  end
  local wsapi_error = {
       write = function (self, err)
         remotedostring("env.error:write(arg(1))", err)
       end
  }
  local wsapi_input =  {
       read = function (self, n)
         return coroutine.yield("RECEIVE", n)
       end
  }
  local wsapi_meta = { 
       __index = function (tab, k)
         local  _, v = remotedostring("return env[arg(1)]", k)
         rawset(tab, k, v)
         return v
    end 
  }
  main_func = function ()
     local wsapi_env = {}
     wsapi_env.error = wsapi_error
     wsapi_env.input = wsapi_input
     setmetatable(wsapi_env, wsapi_meta)
     local status, headers, res = app(wsapi_env)
     remotedostring("status = arg(1)", status)
     for k, v in pairs(headers) do
       if type(v) == "table" then
         remotedostring("headers[arg(1)] = {}", k)
         for _, val in ipairs(v) do
           remotedostring("table.insert(headers[arg(1)], arg(2))", k, val)
         end
       else
         remotedostring("headers[arg(1)] = arg(2)", k, v)
       end
     end
     local s = res()
     while s do
       coroutine.yield("SEND", s)
       s = res()
     end
  end
]==]

init = string.gsub(init, "arg%((%d+)%)", arg)

function run(wsapi_env)
  local state, data
  if RINGER_STATE then
    state, data = RINGER_STATE, RINGER_DATA
    data.status = 500
    data.headers = {}
    data.env = wsapi_env
  else
    data = { status = 500, headers = {}, env = wsapi_env }
    setmetatable(data, { __index = _G })
    state = rings.new(data)
    RINGER_STATE, RINGER_DATA = state, data
    assert(state:dostring(init, RINGER_APP, RINGER_BOOTSTRAP))
  end
  local ok, flag, s, v = state:dostring([[
      main_coro = coroutine.wrap(main_func)
      return main_coro()
  ]])
  repeat
    if not ok then error(flag) end
    if flag == "RECEIVE" then
      ok, flag, s, v = state:dostring("return main_coro(...)",
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
      local ok, flag, s, v = state:dostring("return main_coro()")
      while ok and flag and s do
        if flag == "RECEIVE" then
          ok, flag, s, v = state:dostring("return main_coro(...)",
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
