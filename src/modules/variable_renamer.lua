local VariableRenamer = {}

-- Using characters that look alike visually: l, I, 1, O, 0
-- This makes manual deobfuscation extremely tedious
local CONFUSE_CHARSET = "lIiOo"  -- visually ambiguous

local function confuseName(len)
    len = len or math.random(12, 20)
    local t = {}
    -- Must start with a letter (l or I or i or O or o)
    local starts = {"l","I","i","O","o"}
    t[1] = starts[math.random(#starts)]
    for i = 2, len do
        t[i] = CONFUSE_CHARSET:sub(math.random(1,#CONFUSE_CHARSET),
                                    math.random(1,#CONFUSE_CHARSET))
        -- fallback if sub returns empty
        if t[i] == "" then t[i] = "l" end
    end
    return table.concat(t)
end

-- Ensure uniqueness
local used = {}
local function uniqueName()
    local name
    local attempts = 0
    repeat
        name = confuseName()
        attempts = attempts + 1
        if attempts > 1000 then
            -- fallback to longer name
            name = confuseName(25)
        end
    until not used[name]
    used[name] = true
    return name
end

local reserved_words = {
    ["if"]=true,["then"]=true,["else"]=true,["elseif"]=true,["end"]=true,
    ["for"]=true,["while"]=true,["do"]=true,["repeat"]=true,["until"]=true,
    ["function"]=true,["local"]=true,["return"]=true,["break"]=true,
    ["and"]=true,["or"]=true,["not"]=true,["in"]=true,["nil"]=true,
    ["true"]=true,["false"]=true,["goto"]=true,
}

local lua_builtins = {
    "assert","collectgarbage","dofile","error","getfenv","getmetatable",
    "ipairs","load","loadfile","loadstring","next","pairs","pcall",
    "print","rawequal","rawget","rawlen","rawset","require","select",
    "setfenv","setmetatable","tonumber","tostring","type","unpack","xpcall",
    "_G","_VERSION","math","string","table","os","io","coroutine",
    "debug","package","bit","bit32",
    "game","workspace","script","Instance","Vector3","Vector2","CFrame",
    "Color3","UDim","UDim2","TweenInfo","Enum","wait","spawn","delay",
}

local builtin_set = {}
for _, b in ipairs(lua_builtins) do builtin_set[b] = true end

-- Safe word-boundary replacement (avoids replacing inside strings)
local function replaceWord(code, target, replacement)
    -- pattern: not preceded by word char, not followed by word char
    return (code:gsub('(%f[%w_])' .. target:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1") .. '(%f[^%w_])',
        function() return replacement end))
end

-- Collect all local variable names declared in the code
local function collectLocals(code)
    local vars = {}
    -- local x, y, z = ...
    for decl in code:gmatch("local%s+([%w_%s,]+)%s*=") do
        for v in decl:gmatch("[%w_]+") do
            if not reserved_words[v] and not builtin_set[v] and #v > 1 then
                vars[v] = true
            end
        end
    end
    -- local x (no assignment)
    for v in code:gmatch("local%s+([%w_]+)%s*\n") do
        if not reserved_words[v] and not builtin_set[v] and #v > 1 then
            vars[v] = true
        end
    end
    -- function args: function foo(a, b, c)
    for args in code:gmatch("function%s+[%w_.:]+%s*%(([^)]*)%)") do
        for v in args:gmatch("[%w_]+") do
            if not reserved_words[v] and not builtin_set[v] and #v > 0 then
                vars[v] = true
            end
        end
    end
    -- anonymous function args
    for args in code:gmatch("function%s*%(([^)]*)%)") do
        for v in args:gmatch("[%w_]+") do
            if not reserved_words[v] and not builtin_set[v] and #v > 0 then
                vars[v] = true
            end
        end
    end
    return vars
end

-- Collect top-level function names
local function collectFunctions(code)
    local fns = {}
    for name in code:gmatch("function%s+([%w_]+)%s*%(") do
        if not reserved_words[name] and not builtin_set[name] then
            fns[name] = true
        end
    end
    for name in code:gmatch("local%s+function%s+([%w_]+)%s*%(") do
        if not reserved_words[name] and not builtin_set[name] then
            fns[name] = true
        end
    end
    return fns
end

function VariableRenamer.process(code, options)
    used = {}  -- reset per invocation
    options = options or {}

    -- Preserve string contents
    local strings = {}
    local sidx = 0
    code = code:gsub('"(.-)"', function(s)
        sidx = sidx + 1
        local k = "\0S"..sidx.."\0"
        strings[k] = '"'..s..'"'
        return k
    end)
    code = code:gsub("'(.-)'", function(s)
        sidx = sidx + 1
        local k = "\0S"..sidx.."\0"
        strings[k] = "'"..s.."'"
        return k
    end)

    local varMap = {}

    -- Collect and map locals
    local locals = collectLocals(code)
    for v in pairs(locals) do
        varMap[v] = uniqueName()
    end

    -- Collect and map functions
    local fns = collectFunctions(code)
    for f in pairs(fns) do
        if not varMap[f] then
            varMap[f] = uniqueName()
        end
    end

    -- Apply all replacements (longest first to avoid partial matches)
    local sorted = {}
    for orig in pairs(varMap) do sorted[#sorted+1] = orig end
    table.sort(sorted, function(a,b) return #a > #b end)

    for _, orig in ipairs(sorted) do
        code = replaceWord(code, orig, varMap[orig])
    end

    -- Restore strings
    for k, v in pairs(strings) do
        code = code:gsub(k:gsub("%z","%%z"), function() return v end)
    end

    return code
end

return VariableRenamer
