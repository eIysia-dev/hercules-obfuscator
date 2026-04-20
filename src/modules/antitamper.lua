-- modules/antitamper.lua
local AntiTamper = {}

function AntiTamper.process(code)
    local anti_tamper_code = [[
-- Anti-tamper checks
do
    -- 1. Coroutine integrity
    local _co = coroutine.create(function() coroutine.yield() end)
    coroutine.resume(_co)
    if coroutine.status(_co) ~= "suspended" then return end

    -- 2. Math integrity (catches some hook-based tampering)
    local _pi = math.pi
    if math.abs(_pi - 3.14159265358979) > 1e-10 then return end

    -- 3. String metatable not hooked
    local _mt = getmetatable("")
    if _mt == nil or type(_mt.__index) ~= "table" then return end

    -- 4. pcall integrity
    local _ok, _err = pcall(error, "test", 0)
    if _ok or _err ~= "test" then return end

    -- 5. Detect debug hooks (metamethod hooking)
    if debug and debug.getinfo then
        local _info = debug.getinfo(1, "S")
        if type(_info) ~= "table" then return end
    end

    -- 6. Roblox-specific: game service must be accessible
    local _ok2 = pcall(function()
        local RunService = game:GetService("RunService")
        if not RunService then error("missing") end
    end)
    if not _ok2 then return end

    -- 7. Timestamp-based anti-replay (basic)
    local _t0 = os.clock()
    for i = 1, 100 do end
    local _t1 = os.clock()
    if (_t1 - _t0) > 5 then return end  -- suspiciously slow = debugger?
end
]]

    return anti_tamper_code .. "\n" .. code
end

return AntiTamper
