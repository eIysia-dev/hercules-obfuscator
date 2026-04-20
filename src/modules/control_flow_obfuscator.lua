local ControlFlowObfuscator = {}
math.randomseed(os.time())

local function randName(len)
    len = len or math.random(8, 14)
    local c = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local t = {}
    t[1] = c:sub(math.random(1,26), math.random(1,26))
    for i = 2, len do
        local idx = math.random(1, #c)
        t[i] = c:sub(idx, idx)
    end
    return table.concat(t)
end

local function opaqueTrue()
    local n = math.random(2, 200)
    local opts = {
        string.format("(%d*(%d+1))%%2==0", n, n),
        string.format("%d>=%d", n*n, 0),
        string.format("%d<%d", n, n+math.random(1,50)),
        string.format("type(%d)=='number'", n),
        string.format("#{{},{}}==2"),
    }
    return opts[math.random(#opts)]
end

local function opaqueFalse()
    local n = math.random(1, 100)
    return math.random(1,3) == 1
        and string.format("%d==%d", n, n+1)
        or  string.format("%d>%d", n, n+math.random(1,50))
end

-- Split code into logical chunks at newlines, then build a state-machine dispatcher.
-- Each "block" is assigned a random state ID. A while-loop with a state variable
-- dispatches to each block in order. Automated flattening tools struggle with this
-- because the state transitions are data-dependent.
local function buildDispatcher(code)
    local chunks = {}
    local buffer = {}

    -- Split into lines first (safe preprocessing only)
    local lines = {}
    for line in (code .. "\n"):gmatch("([^\n]*)\n") do
        lines[#lines + 1] = line
    end

    -- Build chunks ONLY at safe boundaries
    local function isBoundary(line)
        local trimmed = line:match("^%s*(.-)%s*$") or ""

        return trimmed == "end"
            or trimmed == "else"
            or trimmed:match("^elseif%s")
            or trimmed:match("^return")
            or trimmed:match("^function%s")
            or trimmed == "break"
    end

    for i = 1, #lines do
        local line = lines[i]
        buffer[#buffer + 1] = line

        -- only split if:
        -- 1) buffer is big enough
        -- 2) AND we're at a safe boundary
        if #buffer >= math.random(6, 12) and isBoundary(line) then
            chunks[#chunks + 1] = table.concat(buffer, "\n")
            buffer = {}
        end
    end

    -- flush remaining
    if #buffer > 0 then
        chunks[#chunks + 1] = table.concat(buffer, "\n")
    end

    if #chunks == 0 then
        return code
    end

    -- stable state IDs (no random reshuffle corruption anymore)
    local stateIds = {}
    for i = 1, #chunks do
        stateIds[i] = i * 100 + math.random(1, 50)
    end

    local stateVar = randName()
    local doneState = math.random(90000, 99999)

    local out = {}

    -- init state
    out[#out + 1] = string.format("local %s = %d", stateVar, stateIds[1])
    out[#out + 1] = string.format("while %s ~= %d do", stateVar, doneState)

    for i = 1, #chunks do
        local thisState = stateIds[i]
        local nextState = stateIds[i + 1] or doneState

        out[#out + 1] = string.format("    if %s == %d then", stateVar, thisState)

        -- inject chunk safely (NO modification of syntax)
        for line in chunks[i]:gmatch("[^\n]+") do
            out[#out + 1] = "        " .. line
        end

        -- safe state transition (no opaque injection inside control flow)
        out[#out + 1] = string.format("        %s = %d", stateVar, nextState)
        out[#out + 1] = "    end"
    end

    out[#out + 1] = "end"

    return table.concat(out, "\n")
end

-- Wrap with opaque predicates at the outermost layer
local function wrapOpaque(code)
    local choice = math.random(1, 4)
    if choice == 1 then
        -- if <true> then <code> else <dead> end
        local dead = string.format("local %s = nil", randName())
        return string.format("if (%s) then\n%s\nelse\n%s\nend", opaqueTrue(), code, dead)
    elseif choice == 2 then
        -- repeat ... until true
        return string.format("repeat\n%s\nuntil true", code)
    elseif choice == 3 then
        -- for i=k,k do ... break end  (runs exactly once)
        local v = randName()
        local n = math.random(1, 1000)
        return string.format("for %s=%d,%d do\n%s\nbreak\nend", v, n, n+10, code)
    else
        return string.format("do\n%s\nend", code)
    end
end

function ControlFlowObfuscator.process(code, max_fake_blocks)
    if type(code) ~= "string" then error("Input must be a string") end
    max_fake_blocks = math.min(max_fake_blocks or 4, 6)

    -- First pass: state-machine dispatcher
    local result = buildDispatcher(code)

    -- Second pass: wrap outer layers with opaque predicates
    local layers = math.random(1, math.max(1, math.floor(max_fake_blocks / 2)))
    for _ = 1, layers do
        result = wrapOpaque(result)
    end

    return result
end

return ControlFlowObfuscator
