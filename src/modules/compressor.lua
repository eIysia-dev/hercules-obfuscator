local Compressor = {}

local LUA_KEYWORDS = {
    "and","break","do","else","elseif","end","false","for","function",
    "goto","if","in","local","nil","not","or","repeat","return",
    "then","true","until","while"
}

function Compressor.process(code)
    if type(code) ~= "string" then error("Input must be string", 2) end
    if #code == 0 then return "" end

    -- Preserve string literals by replacing them with placeholders
    local preserved = {}
    local n = 0
    local function save(s)
        n = n + 1
        local k = "\x00P"..n.."\x00"
        preserved[k] = s
        return k
    end

    -- Long strings [[ ... ]] and [=[ ... ]=]
    code = code:gsub("%[(=*)%[(.-)%]%1%]", function(eq, inner)
        return save("["..eq.."["..inner.."]"..eq.."]")
    end)
    -- Double-quoted strings (handle escaped quotes)
    code = code:gsub('"([^"\\]*(\\.[^"\\]*)*)"', function(s)
        return save('"'..s..'"')
    end)
    -- Single-quoted strings
    code = code:gsub("'([^'\\]*(\\.[^'\\]*)*)'", function(s)
        return save("'"..s.."'")
    end)

    -- Remove long comments
    code = code:gsub("%-%-%[%[.-%]%]", " ")
    code = code:gsub("%-%-%[=%[.-%]=%]", " ")
    -- Remove line comments
    code = code:gsub("%-%-[^\n]*", "")

    -- Collapse all whitespace runs to single space
    code = code:gsub("[ \t\r\n]+", " ")

    -- Remove spaces around most punctuation (safe)
    local punct = {"%(","%)",",%{",",%}","%[","%]","%;",","}
    for _, p in ipairs({",",";","(",")","{","}"}) do
        local ep = p:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
        code = code:gsub(" *" .. ep .. " *", p)
    end

    -- Operators: careful — don't merge `not` `and` `or` into identifiers
    for _, op in ipairs({"%.%.","%.%.%.","%+","%-","%*","%/","%%","%^","#","~=","==","<=",">=","<",">"}) do
        code = code:gsub(" *(" .. op .. ") *", "%1")
    end
    -- = alone (but not == already handled)
    code = code:gsub(" *([^=~<>!])= *([^=])", "%1=%2")

    -- Ensure keywords are always spaced from alphanumerics
    for _, kw in ipairs(LUA_KEYWORDS) do
        code = code:gsub("([%w_])(" .. kw .. ")([^%w_])", "%1 %2%3")
        code = code:gsub("([^%w_])(" .. kw .. ")([%w_])", "%1%2 %3")
    end

    -- Trim
    code = code:match("^%s*(.-)%s*$") or ""

    -- Restore preserved strings
    for k, v in pairs(preserved) do
        -- escape magic chars in key for pattern
        local pat = k:gsub("(%W)", "%%%1")
        code = code:gsub(pat, function() return v end)
    end

    return code
end

return Compressor
