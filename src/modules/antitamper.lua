local AntiTamper = {}

function AntiTamper.process(code)
    local wrapper = [[
local function __fail(reason)
    error("Integrity Check Failed: " .. tostring(reason))
end

-- Safe environment (restricted sandbox)
local env = {
    print = print,
    warn = warn,
    tonumber = tonumber,
    tostring = tostring,
    pairs = pairs,
    ipairs = ipairs,
    math = math,
    string = string,
    table = table,
    type = type,
    pcall = pcall,
    xpcall = xpcall,
    select = select,

    -- explicitly blocked
    os = nil,
    io = nil,
    debug = nil,
    getfenv = nil,
    setfenv = nil,
    loadstring = nil,
    require = require,
}

-- compile user code
local fn, err = loadstring(USER_CODE)
if not fn then
    __fail("compile error: " .. tostring(err))
end

setfenv(fn, env)

local ok, err2 = pcall(fn)
if not ok then
    __fail(err2)
end
]]

    -- inject user code safely
    local escaped = code:gsub("\\", "\\\\")
    wrapper = wrapper:gsub("USER_CODE", string.format("[[%s]]", escaped))

    return wrapper
end

return AntiTamper
