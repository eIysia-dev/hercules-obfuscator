local Wrapper = {}

function Wrapper.process(code)
    return "local args={...} return (function(...) " .. code .. " end)(table.unpack(args))"
end

return Wrapper
