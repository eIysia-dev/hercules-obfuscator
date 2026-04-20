#!/usr/bin/env lua

local Pipeline = require("pipeline")
local config = require("config")

-- =========================
-- API MODE DETECTION
-- =========================
local api_mode = true

local input_file = arg[1]
if not input_file then
    io.stderr:write("No input file provided\n")
    os.exit(1)
end

-- =========================
-- READ INPUT FILE
-- =========================
local f = io.open(input_file, "r")
if not f then
    io.stderr:write("Cannot open input file\n")
    os.exit(1)
end

local code = f:read("*all")
f:close()

-- =========================
-- FLAGS / PRESET PARSING
-- =========================
local preset = nil

for i = 2, #arg do
    if arg[i] == "--min" then preset = "min"
    elseif arg[i] == "--mid" then preset = "mid"
    elseif arg[i] == "--max" then preset = "max"
    end
end

-- =========================
-- APPLY PRESET
-- =========================
local function applyPreset(level)
    if level == "min" then
        config.set("settings.variable_renaming.min_name_length", 10)
        config.set("settings.variable_renaming.max_name_length", 20)
        config.set("settings.garbage_code.garbage_blocks", 5)
        config.set("settings.control_flow.max_fake_blocks", 2)

    elseif level == "mid" then
        config.set("settings.variable_renaming.min_name_length", 40)
        config.set("settings.variable_renaming.max_name_length", 60)
        config.set("settings.garbage_code.garbage_blocks", 25)
        config.set("settings.control_flow.max_fake_blocks", 8)

    elseif level == "max" then
        config.set("settings.variable_renaming.min_name_length", 90)
        config.set("settings.variable_renaming.max_name_length", 120)
        config.set("settings.garbage_code.garbage_blocks", 50)
        config.set("settings.control_flow.max_fake_blocks", 12)
    end
end

if preset then
    applyPreset(preset)
end

-- =========================
-- RUN OBFUSCATION
-- =========================
local success, result = pcall(function()
    return Pipeline.process(code)
end)

if not success then
    io.stderr:write("Obfuscation failed: " .. tostring(result))
    os.exit(1)
end

-- =========================
-- API OUTPUT (IMPORTANT PART)
-- =========================
-- Return ONLY obfuscated code to stdout
io.write(result)
