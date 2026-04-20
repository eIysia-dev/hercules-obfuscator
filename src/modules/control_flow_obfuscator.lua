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
    -- Split into lines/chunks
    local chunks = {}
    local current = {}
    for line in (code .. "\n"):gmatch("([^\n]*)\n") do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed ~= "" then
            current[#current+1] = line
            -- Group ~3 lines per block to reduce bloat
            if #current >= math.random(2, 4) then
                chunks[#chunks+1] = table.concat(current, "\n")
                current = {}
            end
        end
    end
    if #current > 0 then
        chunks[#chunks+1] = table.concat(current, "\n")
    end

    if #chunks == 0 then return code end

    -- Assign shuffled state IDs
    local stateIds = {}
    for i = 1, #chunks do stateIds[i] = i * math.random(10, 99) + math.random(1, 9) end
    -- Shuffle
    for i = #stateIds, 2, -1 do
        local j = math.random(1, i)
        stateIds[i], stateIds[j] = stateIds[j], stateIds[i]
    end

    local stateVar   = randName()
    local doneState  = math.random(9000, 99999)
    local lines = {}
    lines[#lines+1] = string.format("local %s = %d", stateVar, stateIds[1])
    lines[#lines+1] = string.format("while %s ~= %d do", stateVar, doneState)

    for i, chunk in ipairs(chunks) do
        local thisState = stateIds[i]
        local nextState = i < #chunks and stateIds[i+1] or doneState
        lines[#lines+1] = string.format("    if %s == %d then", stateVar, thisState)
        -- Indent the chunk
        for l in (chunk .. "\n"):gmatch("([^\n]*)\n") do
            lines[#lines+1] = "        " .. l
        end
        -- Sprinkle an opaque check before state transition for extra confusion
        if math.random() < 0.4 then
            local dead = randName()
            lines[#lines+1] = string.format("        if not (%s) then local %s=nil end",
                opaqueTrue(), dead)
        end
        lines[#lines+1] = string.format("        %s = %d", stateVar, nextState)
        lines[#lines+1] = "    end"
    end

    lines[#lines+1] = "end"
    return table.concat(lines, "\n")
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
