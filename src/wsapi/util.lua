module("wsapi.util", package.seeall)

----------------------------------------------------------------------------
-- Decode an URL-encoded string (see RFC 2396)
----------------------------------------------------------------------------
function url_decode(str)
  if not str then return nil end
  str = string.gsub (str, "+", " ")
  str = string.gsub (str, "%%(%x%x)", function(h) return string.char(tonumber(h,16)) end)
  str = string.gsub (str, "\r\n", "\n")
  return str
end

----------------------------------------------------------------------------
-- URL-encode a string (see RFC 2396)
----------------------------------------------------------------------------
function url_encode(str)
  if not str then return nil end
  str = string.gsub (str, "\n", "\r\n")
  str = string.gsub (str, "([^%w ])",
	function (c) return string.format ("%%%02X", string.byte(c)) end)
  str = string.gsub (str, " ", "+")
  return str
end

function sanitize(text)
   return text:gsub(">", "&gt;"):gsub("<", "&lt;")
end

function make_rewindable(wsapi_env)
   local new_env = { input = { position = 1, contents = "" } }
   function new_env.input:read(size)
      local left = #self.contents - self.position + 1
      local s
      if left < size then
	 self.contents = self.contents .. wsapi_env.input:read(size - left)
	 s = self.contents:sub(self.position)
	 self.position = #self.contents + 1
      else
	 s = self.contents:sub(self.position, self.position + size)
	 self.position = self.position + size
      end
      if s == "" then return nil else return s end
   end
   function new_env.input:rewind()
      self.position = 1
   end
   return setmetatable(new_env, { __index = wsapi_env, __newindex = wsapi_env })
end
