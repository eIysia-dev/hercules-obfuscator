local StringEncoder = {}

local function makeName(len)
    len = len or math.random(8, 14)
    local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local result = charset:sub(math.random(1,52), math.random(1,52))
    -- ensure single char start
    result = charset:sub(math.random(1,52), math.random(1,52))
    local t = {}
    t[1] = charset:sub(math.random(1,26), math.random(1,26)) -- lowercase start
    for i = 2, len do
        local idx = math.random(1, #charset)
        t[i] = charset:sub(idx, idx)
    end
    return table.concat(t)
end

-- Layer 1: Caesar cipher on alphanumeric chars
local function caesarEncode(s, shift)
    local out = {}
    for i = 1, #s do
        local b = s:byte(i)
        if b >= 65 and b <= 90 then
            out[i] = string.char((b - 65 + shift) % 26 + 65)
        elseif b >= 97 and b <= 122 then
            out[i] = string.char((b - 97 + shift) % 26 + 97)
        elseif b >= 48 and b <= 57 then
            out[i] = string.char((b - 48 + shift) % 10 + 48)
        else
            out[i] = string.char(b)
        end
    end
    return table.concat(out)
end

-- Layer 2: XOR each byte with a rolling key
local function xorEncode(s, key)
    local out = {}
    for i = 1, #s do
        local b = s:byte(i)
        local k = (key * i) % 256
        local xored = 0
        -- pure-Lua XOR
        local a2, b2 = b, k
        local result, bit = 0, 1
        while a2 > 0 or b2 > 0 do
            if a2 % 2 ~= b2 % 2 then result = result + bit end
            a2 = math.floor(a2 / 2)
            b2 = math.floor(b2 / 2)
            bit = bit * 2
        end
        out[i] = string.format("\\%d", result)
    end
    return table.concat(out)
end

-- Build the runtime decode function for layer 1 (caesar)
local function buildCaesarDecoder(fnName, shift)
    local b, r, i = makeName(), makeName(), makeName()
    return string.format([[
local function %s(s)
    local %s={}
    for %s=1,#s do
        local %s=s:byte(%s)
        if %s>=65 and %s<=90 then %s[%s]=string.char((%s-65-%d+26)%%26+65)
        elseif %s>=97 and %s<=122 then %s[%s]=string.char((%s-97-%d+26)%%26+97)
        elseif %s>=48 and %s<=57 then %s[%s]=string.char((%s-48-%d+10)%%10+48)
        else %s[%s]=string.char(%s) end
    end
    return table.concat(%s)
end
]], fnName,
        r, i, b, i,
        b, b, r, i, b, shift,
        b, b, r, i, b, shift,
        b, b, r, i, b, shift,
        r, i, b,
        r)
end

-- Build the runtime XOR decoder
local function buildXORDecoder(fnName, key)
    local i, a2, b2, res, bit2, k = makeName(),makeName(),makeName(),makeName(),makeName(),makeName()
    return string.format([[
local function %s(s)
    local out={}
    for %s=1,#s do
        local %s=s:byte(%s)
        local %s=(%d*%s)%%256
        local %s,%s,%s,%s=0,1,%s,%s
        while %s>0 or %s>0 do
            if %s%%2~=%s%%2 then %s=%s+%s end
            %s=math.floor(%s/2)
            %s=math.floor(%s/2)
            %s=%s*2
        end
        out[%s]=string.char(%s)
    end
    return table.concat(out)
end
]], fnName,
        i, a2, i,
        k, key, i,
        res, bit2, a2, b2, a2, k,
        a2, b2,
        a2, b2, res, res, bit2,
        a2, a2,
        b2, b2,
        bit2, bit2,
        i, res)
end

function StringEncoder.process(code)
    local caesarFn = makeName()
    local xorFn    = makeName()
    local shift    = math.random(3, 22)
    local xorKey   = math.random(3, 127)

    local header = buildCaesarDecoder(caesarFn, shift)
                .. buildXORDecoder(xorFn, xorKey)

    -- Protect escaped quotes
    code = code:gsub('\\"', '\x01\x02'):gsub("\\'", '\x03\x04')

    code = code:gsub("(['\"])(.-)%1", function(quote, str)
        if type(str) ~= "string" then return quote..str..quote end
        str = str:gsub('\x01\x02', '\\"'):gsub('\x03\x04', "\\'")

        -- Decide encoding based on content
        if #str == 0 then
            return quote .. quote
        end

        local layer = math.random(1, 2)
        if layer == 1 then
            -- Caesar only
            local encoded = caesarEncode(str, shift)
                :gsub("\\", "\\\\"):gsub(quote, "\\" .. quote)
            return string.format("%s(%s%s%s)", caesarFn, quote, encoded, quote)
        else
            -- XOR encode (byte-level, embed as escape sequences)
            local encoded = xorEncode(str, xorKey)
            return string.format('%s("%s")', xorFn, encoded)
        end
    end)

    code = code:gsub('\x01\x02', '\\"'):gsub('\x03\x04', "\\'")
    return header .. "\n" .. code
end

return StringEncoder
