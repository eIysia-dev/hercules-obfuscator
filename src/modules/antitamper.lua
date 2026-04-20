local AntiTamper = {}

function AntiTamper.process(code)

local anti_tamper_code = [[

local co1 = coroutine.create(function() end)
local co2 = coroutine.create(function() end)

if type(co1) ~= "thread" or type(co2) ~= "thread" then
    return
end

local f1 = function() end
local f2 = function() end

if type(f1) ~= "function" or type(f2) ~= "function" then
    return
end

if type(debug) ~= "table" then
    return
end

local ok = pcall(function()
    local p = Instance.new("Part")
    return p:GetMass()
end)

if not ok then
    return
end


]]

return anti_tamper_code .. "\n" .. code

end

return AntiTamper
