local Wrapper = {}

function Wrapper.process(code)
    return "local f=function(...) " .. code .. " end return f(...)"
end

return Wrapper
