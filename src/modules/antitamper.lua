local AntiTamper = {}

function AntiTamper.process(code)

return [[
return (function()
    local function fail(reason)
        error("Integrity Check Failed: " .. tostring(reason))
    end

    local function runChecks()

        -- Coroutine identity check (weak heuristic, but kept)
        do
            local co1 = coroutine.create(function() end)
            local co2 = coroutine.create(function() end)

            if tostring(co1) == tostring(co2) then
                return false, "coroutine collision"
            end
        end

        -- Function identity check (heuristic only)
        do
            local f1 = function() end
            local f2 = function() end

            if tostring(f1) == tostring(f2) then
                return false, "function collision"
            end
        end

        -- debug sanity check
        do
            if type(debug) ~= "table" then
                return false, "debug missing"
            end
        end

        -- protected method sanity check
        do
            local p = Instance.new("Part")
            local ok = pcall(function()
                return p:GetMass()
            end)

            if not ok then
                return false, "engine API failure"
            end
        end

        return true
    end

    local ok, reason = runChecks()
    if not ok then
        return fail(reason)
    end

    -- ONLY runs if checks pass
    return (function(...)
]] .. code .. [[
    end)(...)
end)()
]]

end

return AntiTamper
