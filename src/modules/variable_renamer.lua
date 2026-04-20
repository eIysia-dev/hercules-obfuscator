-- modules/variable_renamer.lua (improved)
-- Key improvements:
--   1. Collision-safe name generation
--   2. Full Roblox/Luau global protection list
--   3. String/comment protection during replacement
--   4. Length-sorted replacements to avoid partial substitution bugs
--   5. Visually confusing l/I/i charset for generated names

local VariableRenamer = {}

local used_names = {}

-- All Lua + Luau/Roblox globals that must NOT be renamed
local protected_set = {}
for _, v in ipairs({
    "assert","collectgarbage","dofile","error","ipairs","load",
    "loadfile","loadstring","next","pairs","pcall","print",
    "rawequal","rawget","rawlen","rawset","require","select",
    "setfenv","setmetatable","getmetatable","tonumber","tostring",
    "type","unpack","xpcall","_G","_VERSION","write","sort",
    -- libraries
    "math","string","table","io","os","package","coroutine",
    "bit","bit32","utf8","debug",
    -- Roblox globals
    "game","workspace","script","Instance","Enum","Color3",
    "Vector2","Vector3","CFrame","UDim","UDim2","Rect","Region3",
    "Ray","TweenInfo","NumberSequence","ColorSequence",
    "NumberSequenceKeypoint","ColorSequenceKeypoint",
    "NumberRange","PhysicalProperties","BrickColor",
    "tick","time","wait","delay","spawn","task",
    "warn","typeof","newproxy","shared","plugin","settings",
    "new","fromRGB","fromHSV","Angles","lookAt","identity",
    -- math methods (referenced as math.X — protect base name)
    "abs","acos","asin","atan","atan2","ceil","cos","cosh","deg","exp",
    "floor","fmod","frexp","ldexp","log","log10","max","min","modf",
    "pi","pow","rad","random","randomseed","sin","sinh","sqrt","tan","tanh",
    -- string methods
    "byte","char","dump","find","format","gmatch","gsub","len",
    "lower","match","rep","reverse","sub","upper",
    -- table methods
    "concat","insert","remove","pack","unpack","move","create","resume",
    "yield","status","isyieldable","running","wrap",
}) do protected_set[v] = true end

local reserved_words = {
    ["if"]=true,["then"]=true,["else"]=true,["elseif"]=true,["end"]=true,
    ["for"]=true,["while"]=true,["do"]=true,["repeat"]=true,["until"]=true,
    ["function"]=true,["local"]=true,["return"]=true,["break"]=true,
    ["continue"]=true,["and"]=true,["or"]=true,["not"]=true,
    ["in"]=true,["nil"]=true,["true"]=true,["false"]=true,
}

local DEFAULT_MIN = 8
local DEFAULT_MAX = 16

-- l/I/i visually ambiguous charset
local CHARS = {"l","I","i","L"}

local function generateName(min_len, max_len)
    local name, attempts
    repeat
        attempts = (attempts or 0) + 1
        local len = math.random(min_len, max_len)
        local parts = {CHARS[math.random(#CHARS)]}
        for j = 2, len do parts[j] = CHARS[math.random(#CHARS)] end
        name = table.concat(parts)
    until not used_names[name] and not reserved_words[name] and not protected_set[name]
    used_names[name] = true
    return name
end

-- Protect strings/comments, apply fn, restore
local function withProtectedStrings(code, fn)
    local slots, idx = {}, 0
    local function save(s) idx=idx+1; slots[idx]=s; return "\0S"..idx.."\0" end

    code = code:gsub("%[(=*)%[(.-)%]%1%]", function(eq,c) return save("["..eq.."["..c.."]"..eq.."]") end)
    code = code:gsub('"(.-)"', function(s) return save('"'..s..'"') end)
    code = code:gsub("'(.-)'", function(s) return save("'"..s.."'") end)
    code = code:gsub("%-%-[^\n]*", function(s) return save(s) end)

    code = fn(code)

    code = code:gsub("\0S(%d+)\0", function(i) return slots[tonumber(i)] end)
    return code
end

local function safeReplace(src, old, new)
    local escaped = old:gsub("[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")
    return (src:gsub("%f[%w_]("..escaped..")%f[^%w_]", new))
end

function VariableRenamer.process(code, options)
    options = options or {}
    local min_len = options.min_length or DEFAULT_MIN
    local max_len = options.max_length or DEFAULT_MAX

    used_names = {}
    local var_map = {}

    local function addMapping(name)
        if #name > 1 and not reserved_words[name] and not protected_set[name] and not var_map[name] then
            var_map[name] = generateName(min_len, max_len)
        end
    end

    -- Collect local vars
    for vars in code:gmatch("local%s+([%w_,%s]+)%s*=") do
        for v in vars:gmatch("[%w_]+") do addMapping(v) end
    end
    -- Collect function names + params
    for fname, params in code:gmatch("local%s+function%s+([%w_]+)%s*%(([^%)]*)%)") do
        addMapping(fname)
        for p in params:gmatch("[%w_]+") do addMapping(p) end
    end
    for fname, params in code:gmatch("function%s+([%w_]+)%s*%(([^%)]*)%)") do
        if not fname:match("[:%.]") then addMapping(fname) end
        for p in params:gmatch("[%w_]+") do addMapping(p) end
    end

    code = withProtectedStrings(code, function(src)
        -- Sort longest-first to avoid partial replacements (e.g. "foo" inside "fooBar")
        local sorted = {}
        for old, new in pairs(var_map) do sorted[#sorted+1] = {old=old,new=new} end
        table.sort(sorted, function(a,b) return #a.old > #b.old end)
        for _, pair in ipairs(sorted) do
            src = safeReplace(src, pair.old, pair.new)
        end
        return src
    end)

    return code
end

return VariableRenamer
