-- IRON SOUL - STABLE WORLD RECON ENTRY
local url =
    "https://raw.githubusercontent.com/"
    .. "MUshihara/ironsoulkaitun/main/diagnostics/world_recon_v61_11.lua"
    .. "?t="
    .. tostring(os.time())

local source = game:HttpGet(url)
local fn, err = loadstring(source)
assert(fn, err)
return fn()
