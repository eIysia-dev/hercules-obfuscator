#!/usr/bin/env lua

local Pipeline = require("pipeline")
local config = require("config")

-- =========================
-- API MODE FLAG
-- =========================
local API_MODE = false
for i = 1, #arg do
    if arg[i] == "--api" then
        API_MODE = true
    end
end

-- =========================
-- UTILS
-- =========================

local function filesize(file)
    local f = io.open(file, "r")
    if not f then return 0 end
    local sz
    local success = pcall(function()
        sz = f:seek("end")
    end)
    f:close()
    if not success then return 0 end
    return sz
end

local function map(func, tbl)
    local mapped = {}
    for k, v in pairs(tbl) do
        mapped[k] = func(v, k)
    end
    return mapped
end

local colors = {
    reset = "\27[0m",
    green = "\27[32m",
    red = "\27[31m",
    white = "\27[37m",
    cyan = "\27[36m",
    blue = "\27[34m",
    yellow = "\27[33m"
}

local obfuscated_list = {}

local BANNER = colors.blue .. [[
                                _                      _        __   
  /\  /\ ___  _ __  ___  _   _ | |  ___  ___   __   __/ |      / /_  
 / /_/ // _ \| '__|/ __|| | | || | / _ \/ __|  \ \ / /| |     | '_ \ 
/ __  /|  __/| |  | (__ | |_| || ||  __/\__ \   \ V / | |  _  | (_) |
\/ /_/  \___||_|   \___| \__,_||_| \___||___/    \_/  |_| (_)  \___/ 
]] .. colors.reset

-- =========================
-- SANITY CHECK
-- =========================
local function runSanityCheck(original_code, obfuscated_code)
    local function captureOutput(code)
        local output = {}
        local ogprint = _G.print

        local success, result = pcall(function()
            _G.print = function(...)
                local args = {...}
                table.insert(output, table.concat(map(tostring, args), "\t"))
            end

            local func, err = load(code)
            if not func then error(err) end
            local ok, run_err = pcall(func)
            if not ok then error(run_err) end
        end)

        _G.print = ogprint

        if not success then
            return "", result
        end

        return table.concat(output, "\n"), nil
    end

    local o1, e1 = captureOutput(original_code)
    local o2, e2 = captureOutput(obfuscated_code)

    if e1 or e2 then
        return false, { expected = e1 or o1, got = e2 or o2 }
    end

    return o1 == o2, { expected = o1, got = o2 }
end

-- =========================
-- CLI RESULT PRINTER
-- =========================
local function printCliResult(input, output, time, options)
    if API_MODE then return end

    local original_size = filesize(input)
    local obfuscated_size = output and filesize(output) or 0

    local size_diff_percent = "N/A"
    if original_size > 0 then
        size_diff_percent =
            string.format("%.2f", ((obfuscated_size - original_size) / original_size) * 100 + 100)
    end

    local line = colors.white .. string.rep("═", 65) .. colors.reset

    print("\n" .. line)
    print(BANNER)
    print(colors.white .. "Obfuscation Complete!" .. colors.reset)
    print(line)
    print("Time Taken        : " .. string.format("%.2f", time) .. "s")
    print("Original Size     : " .. original_size)
    print("Obfuscated Size   : " .. obfuscated_size)
    print("Size Difference   : " .. size_diff_percent .. "%")
    print(line .. "\n")
end

-- =========================
-- PRESETS
-- =========================
local function applyPreset(level)
    if level == "min" then
        config.set("settings.variable_renaming.min_name_length", 10)
    elseif level == "mid" then
        config.set("settings.variable_renaming.min_name_length", 40)
    elseif level == "max" then
        config.set("settings.variable_renaming.min_name_length", 90)
    end
end

-- =========================
-- USAGE
-- =========================
local function printUsage()
    print("Usage: ./hercules.lua file.lua [options]")
    os.exit(1)
end

-- =========================
-- MAIN
-- =========================
local function main()
    if #arg < 1 then
        printUsage()
    end

    local input = arg[1]
    local file = io.open(input, "r")
    if not file then error("File not found") end

    local code = file:read("*all")
    file:close()

    local start_time = os.clock()

    local obfuscated_code = Pipeline.process(code)

    local output_file = input:gsub("%.lua$", "_obfuscated.lua")

    local out = io.open(output_file, "w")
    out:write(obfuscated_code)
    out:close()

    local elapsed = os.clock() - start_time

    -- =========================
    -- API MODE OUTPUT (CLEAN)
    -- =========================
    if API_MODE then
        io.write(obfuscated_code)
        os.exit(0)
    end

    -- =========================
    -- CLI MODE OUTPUT
    -- =========================
    printCliResult(input, output_file, elapsed, {})
end

main()
