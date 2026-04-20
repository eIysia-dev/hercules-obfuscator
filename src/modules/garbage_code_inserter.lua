local GarbageCodeInserter = {}

local LOWERCASE_A, LOWERCASE_Z = 97, 122
local MAX_RANDOM_NUMBER = 100
local MAX_LOOP_COUNT = 10
local VARIABLE_NAME_LENGTH = 6

local function generateRandomVariableName()
    local name = {}
    -- first char must be a letter
    name[1] = string.char(math.random(LOWERCASE_A, LOWERCASE_Z))
    for i = 2, VARIABLE_NAME_LENGTH do
        local r = math.random(1, 3)
        if r == 1 then
            name[i] = string.char(math.random(LOWERCASE_A, LOWERCASE_Z))
        elseif r == 2 then
            name[i] = string.char(math.random(65, 90))
        else
            name[i] = string.char(math.random(48, 57))
        end
    end
    return table.concat(name)
end

local function generateRandomNumber(max)
    return math.random(1, max or MAX_RANDOM_NUMBER)
end

local dead_values = {
    function() return string.format("local %s = nil; if %s ~= nil then error('x') end", generateRandomVariableName(), generateRandomVariableName()) end,
    function() return string.format("local %s = {%d,%d,%d}", generateRandomVariableName(), generateRandomNumber(), generateRandomNumber(), generateRandomNumber()) end,
    function() return string.format("local %s = tostring(%d)", generateRandomVariableName(), generateRandomNumber()) end,
    function() return string.format("local %s = math.floor(%d.%d)", generateRandomVariableName(), generateRandomNumber(), generateRandomNumber()) end,
    function() return string.format("local %s = type(nil) == 'nil'", generateRandomVariableName()) end,
    function() return string.format("local %s = string.len('%s')", generateRandomVariableName(), generateRandomVariableName()) end,
}

local code_types = {
    variable = function()
        return string.format("local %s = %d", generateRandomVariableName(), generateRandomNumber())
    end,
    dead_assign = function()
        return dead_values[math.random(#dead_values)]()
    end,
    while_loop = function()
        return string.format("while %s do local _ = %d break end",
            tostring(math.random() > 0.5),
            generateRandomNumber(100)
        )
    end,
    for_loop = function()
        return string.format("for %s = 1, %d do local _ = %d end",
            generateRandomVariableName(),
            generateRandomNumber(MAX_LOOP_COUNT),
            generateRandomNumber()
        )
    end,
    if_statement = function()
        return string.format("if %s then local _ = %d end",
            tostring(math.random() > 0.5),
            generateRandomNumber()
        )
    end,
    function_def = function()
        return string.format("local function %s(%s) local _ = %d end",
            generateRandomVariableName(),
            generateRandomVariableName(),
            generateRandomNumber()
        )
    end,
    do_block = function()
        return string.format("do local %s = %d local %s = %s + 1 end",
            generateRandomVariableName(), generateRandomNumber(),
            generateRandomVariableName(), generateRandomVariableName()
        )
    end,
}

local code_type_keys = {}
for k in pairs(code_types) do table.insert(code_type_keys, k) end

local function generateRandomCode()
    return code_types[code_type_keys[math.random(#code_type_keys)]]()
end

local function generateGarbage(blocks, sep)
    sep = sep or "\n"
    local garbage_code = {}
    for i = 1, blocks do
        table.insert(garbage_code, generateRandomCode())
    end
    return table.concat(garbage_code, sep)
end

function GarbageCodeInserter.process(code, garbage_blocks)
    if type(code) ~= "string" or #code == 0 then
        error("Input code must be a non-empty string", 2)
    end
    if type(garbage_blocks) ~= "number" then
        error("garbage_blocks must be a number", 2)
    end
    local prefix_garbage = generateGarbage(garbage_blocks)
    local suffix_garbage = generateGarbage(garbage_blocks)
    return table.concat({prefix_garbage, code, suffix_garbage}, "\n")
end

-- Scatter garbage between lines of existing code
function GarbageCodeInserter.scatter(code, density)
    if type(code) ~= "string" or #code == 0 then
        error("Input code must be a non-empty string", 2)
    end
    density = density or 3
    local lines = {}
    for line in (code .. "\n"):gmatch("([^\n]*)\n") do
        lines[#lines + 1] = line
    end
    local result = {}
    for _, line in ipairs(lines) do
        result[#result + 1] = line
        if math.random(1, 10) <= density then
            result[#result + 1] = generateRandomCode()
        end
    end
    return table.concat(result, "\n")
end

function GarbageCodeInserter.setSeed(seed)
    math.randomseed(seed)
end

return GarbageCodeInserter
