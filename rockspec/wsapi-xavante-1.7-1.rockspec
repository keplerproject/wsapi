package = "WSAPI-Xavante"

version = "1.7-1"

description = {
  summary = "Lua Web Server API - Xavante Handler",
  detailed = [[
    WSAPI is an API that abstracts the web server from Lua web applications. This is the rock
    that contains the Xavante adapter and launcher.
  ]],
  license = "MIT/X11",
  homepage = "http://www.keplerproject.org/wsapi"
}

dependencies = { "wsapi >= 1.6.1", "xavante >= 2.3.0" }

source = {
  url = "git://github.com/keplerproject/wsapi",
  tag = "v1.7",
}

build = {
  type = "builtin",
  modules = {
    ["wsapi.xavante"] = "src/wsapi/xavante.lua"
  },
  install = { bin = { "src/launcher/wsapi" } }
}
