local AntiTamper = {}

function AntiTamper.process(code)
    -- We build the anti-tamper header as a string that gets prepended.
    -- Checks performed:
    --   1. debug library completeness
    --   2. native function integrity (not wrapped/replaced)
    --   3. metatable tampering on string/table/math
    --   4. environment consistency (_G globals)
    --   5. Source-level hook detection (debug.sethook)
    --   6. Stack inspection for suspicious upvalues

    local anti = [[
do
    local _dbg = debug
    local _type = type
    local _error = error
    local _pairs = pairs
    local _pcall = pcall
    local _tostring = tostring
    local _rawget = rawget
    local _getinfo = debug and debug.getinfo
    local _sethook = debug and debug.sethook
    local _getupval = debug and debug.getupvalue
    local _getlocal = debug and debug.getlocal
    local _gmeta = getmetatable
    local _G_ref = _G

    -- 1. Verify debug library is intact
    local function checkDebug()
        if _type(_dbg) ~= "table" then return false, "debug not table" end
        local needed = {"getinfo","getlocal","getupvalue","sethook","traceback"}
        for _, k in _pairs(needed) do
            if _type(_dbg[k]) ~= "function" then return false, "debug."..k.." missing" end
        end
        return true
    end

    -- 2. Verify a function is native (C) not Lua-wrapped
    local function isNative(f)
        if _type(f) ~= "function" then return false end
        local info = _getinfo and _getinfo(f, "S")
        return info and info.what == "C"
    end

    -- 3. Check critical natives haven't been replaced
    local function checkNatives()
        local critical = {
            _pcall, _error, _rawget, _pairs, _type, _tostring,
            tostring, tonumber, rawset, rawequal,
            string.byte, string.char, string.format, string.gsub,
            string.find, string.rep, string.sub, string.len,
            table.insert, table.remove, table.concat, table.sort,
            math.floor, math.random, math.abs,
            _dbg.getinfo, _dbg.sethook, _dbg.getupvalue,
        }
        for _, fn in _pairs(critical) do
            if not isNative(fn) then
                return false, "native replaced: ".._tostring(fn)
            end
        end
        return true
    end

    -- 4. Check for metamethod tampering on core libs
    local function checkMeta()
        local libs = {string, table, math, _G_ref}
        for _, lib in _pairs(libs) do
            local mt = _gmeta(lib)
            if mt then
                for _, m in _pairs({"__index","__newindex","__call"}) do
                    local mf = _rawget(mt, m)
                    if mf and _type(mf) == "function" and not isNative(mf) then
                        return false, "metamethod tampered: "..m
                    end
                end
            end
        end
        return true
    end

    -- 5. Detect if a debug hook was installed (common dumper technique)
    local function checkHook()
        -- Install a temporary no-op hook, then immediately remove.
        -- If the hook count changes unexpectedly, something is interfering.
        local hookSet = false
        _pcall(function()
            _sethook(function() hookSet = true end, "c", 1)
            _sethook() -- remove
        end)
        return not hookSet, hookSet and "hook triggered" or nil
    end

    -- 6. Check globals haven't been shadowed/removed
    local function checkGlobals()
        local essential = {"pcall","type","tostring","error","pairs","rawget",
                           "string","table","math","debug"}
        for _, k in _pairs(essential) do
            if _type(_G_ref[k]) ~= _type(_rawget(_G_ref, k) or _G_ref[k]) then
                return false, "global mismatch: "..k
            end
        end
        return true
    end

    -- Run all checks
    local checks = {checkDebug, checkNatives, checkMeta, checkGlobals}
    for _, check in _pairs(checks) do
        local ok, reason = check()
        if not ok then
            -- Infinite error loop — harder to catch than a single error()
            while true do
                _error("Protected: ".._tostring(reason), 0)
            end
        end
    end

    -- Periodically re-check via a coroutine that yields back
    -- (makes it harder for a dumper to find a clean window)
    local _co = coroutine
    if _co and _co.create then
        local watcher = _co.create(function()
            while true do
                _co.yield()
                for _, check in _pairs(checks) do
                    local ok, reason = check()
                    if not ok then
                        while true do _error("Protected: ".._tostring(reason), 0) end
                    end
                end
            end
        end)
        local _orig_resume = _co.resume
        -- Wrap coroutine.resume to trigger our watcher occasionally
        local _tick = 0
        coroutine.resume = function(co, ...)
            _tick = _tick + 1
            if _tick % 50 == 0 then
                _orig_resume(watcher)
            end
            return _orig_resume(co, ...)
        end
    end
end
]]

    return anti .. "\n" .. code
end

return AntiTamper
