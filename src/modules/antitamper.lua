local AntiTamper = {}
-- anti beautify + simple anti tamper for now
function AntiTamper.process(code)
  local anti_tamper_code = [[
print("hi")
]]
  return anti_tamper_code .. "\n" .. code
end

return AntiTamper
