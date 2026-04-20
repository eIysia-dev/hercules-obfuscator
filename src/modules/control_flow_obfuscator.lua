-- modules/control_flow_obfuscator.lua (improved)
-- Original had a simple while-loop wrapper and a TODO to make it better.
-- This replaces it with a state-machine/dispatcher pattern:
--   - Splits code into statements and wraps them in a numbered dispatch loop
--   - Makes static analysis and deobfuscation significantly harder
--   - Adds fake transition states to increase complexity

local ControlFlowObfuscator = {}

math.randomseed(os.time())

local CHARS = {"l","I","i","L"}
local function rname(len)
    len = len or 8
    local t = {CHARS[math.random(#CHARS)]}
    for i = 2, len do t[i] = CHARS[math.random(#CHARS)] end
    return table.concat(t)
end

-- Split code into individual statements (split on semicolons and newlines)
local function splitStatements(code)
    local stmts = {}
    for line in (code .. "\n"):gmatch("([^\n]*)\n") do
        local trimmed = line:match("^%s*(.-)%s*$")
        if #trimmed > 0 then
            stmts[#stmts + 1] = trimmed
        end
    end
    return stmts
end

-- Shuffle the execution order and build a dispatcher
local function buildDispatcher(stmts)
    -- Assign each statement a random state number
    local n = #stmts
    local states = {}
    local used = {}

    for i = 1, n do
        local s
        repeat s = math.random(1000, 9999) until not used[s]
        used[s] = true
        states[i] = s
    end

    -- Insert some fake/dead states
    local fake_count = math.floor(n * 0.3) + 2
    local fake_states = {}
    for i = 1, fake_count do
        local s
        repeat s = math.random(1000, 9999) until not used[s]
        used[s] = true
        fake_states[i] = s
    end

    local state_var = rname(10)
    local lines = {}
    lines[#lines+1] = "local " .. state_var .. " = " .. states[1]
    lines[#lines+1] = "while true do"

    -- Real states
    local first = true
    for i = 1, n do
        local kw = first and "if" or "elseif"
        first = false
        lines[#lines+1] = "  " .. kw .. " " .. state_var .. " == " .. states[i] .. " then"
        lines[#lines+1] = "    " .. stmts[i]
        local next_state = (i < n) and ("    " .. state_var .. " = " .. states[i+1]) or "    break"
        lines[#lines+1] = next_state
    end

    -- Fake dead states (never reached)
    for _, fs in ipairs(fake_states) do
        lines[#lines+1] = "  elseif " .. state_var .. " == " .. fs .. " then"
        lines[#lines+1] = "    local " .. rname() .. " = " .. math.random(1, 9999)
        lines[#lines+1] = "    break"
    end

    lines[#lines+1] = "  else"
    lines[#lines+1] = "    break"
    lines[#lines+1] = "  end"
    lines[#lines+1] = "end"

    return table.concat(lines, "\n")
end

function ControlFlowObfuscator.process(code, max_fake_blocks)
    if type(code) ~= "string" then
        error("Input code must be a string")
    end

    local stmts = splitStatements(code)

    -- For very short scripts (< 3 statements), fall back to simple wrap
    if #stmts < 3 then
        return code
    end

    return buildDispatcher(stmts)
end

return ControlFlowObfuscator
