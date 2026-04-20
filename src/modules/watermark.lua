-- modules/watermark.lua
local Watermark = {}

function Watermark.process(code)
    return "--[elysium was here! | discord.gg/Elys1um]\n" .. code
end

return Watermark
