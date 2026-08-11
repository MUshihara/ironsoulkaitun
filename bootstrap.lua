-- IRON SOUL KAITUN - STABLE ENTRY
-- Keep the historical bootstrap URL working while the active runtime lives
-- in a versioned bootstrap file.

local url =
    "https://raw.githubusercontent.com/"
    .. "MUshihara/ironsoulkaitun/main/bootstrap_v61_9.lua"
    .. "?t="
    .. tostring(os.time())

local source = game:HttpGet(url)
local fn, err = loadstring(source)
assert(fn, err)
return fn()
