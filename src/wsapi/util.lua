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
