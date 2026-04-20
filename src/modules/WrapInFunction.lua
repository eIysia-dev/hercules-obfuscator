local Wrapper = {}

function Wrapper.process(code)
    return "local _args={...} return (function(...) " .. code .. " end)(table.unpack(_args))"
end

return Wrapper
