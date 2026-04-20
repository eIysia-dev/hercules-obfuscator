local Watermark = {}

function Watermark.process(code)
    -- Visible header comment
    local header = "--[elysium was here :) | discord.gg/Elys1um]\n"
    -- Hidden watermark: embedded as an unreachable dead string literal
    -- that will appear in the bytecode constants table, making it
    -- easy to identify the tool while being invisible at runtime
    local hidden = string.format(
        "do local _ = '%s' end\n",
        "elysium_was_here_" .. tostring(math.random(100000, 999999))
    )
    return header .. hidden .. code
end

return Watermark
