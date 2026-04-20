-- modules/garbage_code_inserter.lua (improved)
-- Improvements over original:
--   1. Injects garbage BETWEEN lines (not just prefix/suffix) - harder to strip
--   2. More varied and realistic-looking dead code patterns
--   3. Uses l/I/i confusing names to blend with obfuscated vars
--   4. Density scales with code size

local GarbageCodeInserter = {}

local CHARS = {"l","I","i","L"}
local function rname(len)
    len = len or 6
    local t = {}
    for i = 1, len do t[i] = CHARS[math.random(#CHARS)] end
    return table.concat(t)
end

local function rnum(max) return math.random(1, max or 100) end

local generators = {
    function() return string.format("local %s = %d", rname(), rnum()) end,
    function() return string.format("local %s = %d * %d + %d", rname(), rnum(50), rnum(10), rnum(20)) end,
    function() return string.format("if false then local %s = %d end", rname(), rnum()) end,
    function() return string.format("do local %s = {} end", rname()) end,
    function()
        return string.format("local %s = (function() return %d end)()", rname(), rnum())
    end,
    function()
        return string.format("local %s = math.floor(%d / %d)", rname(), rnum(999), rnum(9) + 1)
    end,
    function()
        return string.format("local %s = {%d, %d, %d}", rname(), rnum(), rnum(), rnum())
    end,
    function()
        return string.format("local %s = tostring(%d)", rname(), rnum())
    end,
    function()
        return string.format("if %d > %d then else end", rnum(50), rnum(50) + 51)
    end,
    function()
        local n1, n2 = rnum(999), rnum(999)
        return string.format("local %s = %d + %d - %d", rname(), n1, n2, n1)
    end,
}

local function makeGarbage(n)
    local lines = {}
    for i = 1, n do
        lines[i] = generators[math.random(#generators)]()
    end
    return lines
end

function GarbageCodeInserter.process(code, garbage_blocks)
    if type(code) ~= "string" or #code == 0 then
        error("Input code must be a non-empty string", 2)
    end
    garbage_blocks = garbage_blocks or 20

    local lines = {}
    for line in (code .. "\n"):gmatch("([^\n]*)\n") do
        lines[#lines + 1] = line
    end

    local result = {}

    -- Prefix block
    for _, g in ipairs(makeGarbage(math.floor(garbage_blocks * 0.4))) do
        result[#result + 1] = g
    end

    -- Inject inline between real lines
    local inject_every = math.max(3, math.floor(#lines / (garbage_blocks * 0.3)))
    for i, line in ipairs(lines) do
        result[#result + 1] = line
        if i % inject_every == 0 then
            for _, g in ipairs(makeGarbage(math.random(1, 2))) do
                result[#result + 1] = g
            end
        end
    end

    -- Suffix block
    for _, g in ipairs(makeGarbage(math.floor(garbage_blocks * 0.4))) do
        result[#result + 1] = g
    end

    return table.concat(result, "\n")
end

return GarbageCodeInserter
