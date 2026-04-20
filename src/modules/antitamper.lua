local AntiTamper = {}

function AntiTamper.process(code)

local anti_tamper_code = [[
do
    local function fail(reason)
        return error("Integrity Check Failed: " .. tostring(reason))
    end

    local function safePcall(fn)
        return pcall(fn)
    end

    -- 1. Metatable immutability check (safe form)
    do
        local mt = getrawmetatable(game)
        if not mt then fail("missing metatable") end

        local old = mt.__index

        local ok = safePcall(function()
            mt.__index = nil
        end)

        mt.__index = old

        if ok then
            return fail("metatable writable")
        end
    end

    -- 2. Coroutine identity check (simplified)
    do
        local co1 = coroutine.create(function() end)
        local co2 = coroutine.create(function() end)

        if tostring(co1) == tostring(co2) then
            return fail("coroutine identity collision")
        end
    end

    -- 3. Function identity check
    do
        local f1 = function() end
        local f2 = function() end

        if tostring(f1) == tostring(f2) then
            return fail("function identity collision")
        end
    end

    -- 4. BindableEvent sanity check
    do
        local event = Instance.new("BindableEvent")
        local fired = false

        event.Event:Connect(function()
            fired = true
        end)

        event:Fire()

        if not fired then
            return fail("event system broken")
        end
    end

    -- 5. debug library validation (safe existence checks only)
    do
        if type(debug) ~= "table" then
            return fail("debug missing")
        end
    end

    -- 6. Instance hierarchy sanity
    do
        local part = Instance.new("Part")
        local folder = Instance.new("Folder")

        part.Parent = folder

        if part.Parent ~= folder then
            return fail("instance hierarchy mismatch")
        end
    end

    -- 7. Protected method sanity (non-invasive)
    do
        local p = Instance.new("Part")
        local ok = pcall(function()
            return p:GetMass()
        end)

        if not ok then
            return fail("protected method failure")
        end
    end

end
]]

return anti_tamper_code .. "\n" .. code

end

return AntiTamper
