local Wrapper = {}
function Wrapper.process(code)
    return [[return (function(...)do]] .. code .. [[end end)(...)]]
end
return Wrapper
