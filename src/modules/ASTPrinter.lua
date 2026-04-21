local Printer = {}

function Printer.new()
    local self = { output = {}, indent = 0 }
    setmetatable(self, { __index = Printer })
    return self
end

function Printer:emit(s)
    table.insert(self.output, s)
end

function Printer:emitIndent()
    self:emit(string.rep("    ", self.indent))
end

function Printer:toString()
    return table.concat(self.output)
end

function Printer:printStat(node)
    local k = node.kind
    if k == "StatBlock" then
        for _, s in ipairs(node.body) do
            self:printStat(s)
        end
    elseif k == "StatLocal" then
        self:emitIndent()
        self:emit("local ")
        for i, v in ipairs(node.vars) do
            if i > 1 then self:emit(", ") end
            self:emit(v.name)
            if v.annotation then
                self:emit(": ")
                self:printType(v.annotation)
            end
        end
        if #node.values > 0 then
            self:emit(" = ")
            for i, v in ipairs(node.values) do
                if i > 1 then self:emit(", ") end
                self:printExpr(v)
            end
        end
        self:emit("\n")
    elseif k == "StatAssign" then
        self:emitIndent()
        for i, v in ipairs(node.vars) do
            if i > 1 then self:emit(", ") end
            self:printExpr(v)
        end
        self:emit(" = ")
        for i, v in ipairs(node.values) do
            if i > 1 then self:emit(", ") end
            self:printExpr(v)
        end
        self:emit("\n")
    elseif k == "StatExpr" then
        self:emitIndent()
        self:printExpr(node.expr)
        self:emit("\n")
    elseif k == "StatReturn" then
        self:emitIndent()
        self:emit("return")
        if #node.list > 0 then
            self:emit(" ")
            for i, v in ipairs(node.list) do
                if i > 1 then self:emit(", ") end
                self:printExpr(v)
            end
        end
        self:emit("\n")
    elseif k == "StatIf" then
        self:emitIndent()
        self:emit("if ")
        self:printExpr(node.condition)
        self:emit(" then\n")
        self.indent += 1
        self:printStat(node.thenbody)
        self.indent -= 1
        if node.elsebody then
            if node.elsebody.kind == "StatIf" then
                self:emitIndent()
                self:emit("else")
                self:printStat(node.elsebody)
            else
                self:emitIndent()
                self:emit("else\n")
                self.indent += 1
                self:printStat(node.elsebody)
                self.indent -= 1
                self:emitIndent()
                self:emit("end\n")
            end
        else
            self:emitIndent()
            self:emit("end\n")
        end
    elseif k == "StatWhile" then
        self:emitIndent()
        self:emit("while ")
        self:printExpr(node.condition)
        self:emit(" do\n")
        self.indent += 1
        self:printStat(node.body)
        self.indent -= 1
        self:emitIndent()
        self:emit("end\n")
    elseif k == "StatRepeat" then
        self:emitIndent()
        self:emit("repeat\n")
        self.indent += 1
        self:printStat(node.body)
        self.indent -= 1
        self:emitIndent()
        self:emit("until ")
        self:printExpr(node.condition)
        self:emit("\n")
    elseif k == "StatFor" then
        self:emitIndent()
        self:emit("for " .. node.var.name .. " = ")
        self:printExpr(node.from)
        self:emit(", ")
        self:printExpr(node.to)
        if node.step then
            self:emit(", ")
            self:printExpr(node.step)
        end
        self:emit(" do\n")
        self.indent += 1
        self:printStat(node.body)
        self.indent -= 1
        self:emitIndent()
        self:emit("end\n")
    elseif k == "StatForIn" then
        self:emitIndent()
        self:emit("for ")
        for i, v in ipairs(node.vars) do
            if i > 1 then self:emit(", ") end
            self:emit(v.name)
        end
        self:emit(" in ")
        for i, v in ipairs(node.values) do
            if i > 1 then self:emit(", ") end
            self:printExpr(v)
        end
        self:emit(" do\n")
        self.indent += 1
        self:printStat(node.body)
        self.indent -= 1
        self:emitIndent()
        self:emit("end\n")
    elseif k == "StatFunction" then
        self:emitIndent()
        self:emit("function ")
        self:printExpr(node.name)
        self:printFuncBody(node.func)
    elseif k == "StatLocalFunction" then
        self:emitIndent()
        self:emit("local function " .. (node.name and node.name.name or "_"))
        self:printFuncBody(node.func)
    elseif k == "StatBreak" then
        self:emitIndent()
        self:emit("break\n")
    elseif k == "StatContinue" then
        self:emitIndent()
        self:emit("continue\n")
    elseif k == "StatTypeAlias" then
        -- skip type aliases in output (or emit them)
        self:emitIndent()
        self:emit("type " .. node.name .. " = ")
        self:printType(node.type)
        self:emit("\n")
    elseif k == "StatError" then
        -- skip errors
    else
        self:emitIndent()
        self:emit("-- unhandled stat: " .. tostring(k) .. "\n")
    end
end

local BINARY_OPS = {
    [0]="+",[1]="-",[2]="*",[3]="/",[4]="//",[5]="%",[6]="^",[7]="..",
    [8]="~=",[9]="==",[10]="<",[11]="<=",[12]=">",[13]=">=",[14]="and",[15]="or"
}
local UNARY_OPS = { [0]="not ",[1]="-",[2]="#" }

function Printer:printExpr(node)
    local k = node.kind
    if k == "ExprConstantNil" then
        self:emit("nil")
    elseif k == "ExprConstantBool" then
        self:emit(node.value and "true" or "false")
    elseif k == "ExprConstantNumber" then
        self:emit(tostring(node.value))
    elseif k == "ExprConstantString" then
        self:emit(string.format("%q", node.value))
    elseif k == "ExprLocal" then
        self:emit(node["local"].name)
    elseif k == "ExprGlobal" then
        self:emit(node.name)
    elseif k == "ExprVarargs" then
        self:emit("...")
    elseif k == "ExprGroup" then
        self:emit("(")
        self:printExpr(node.expr)
        self:emit(")")
    elseif k == "ExprUnary" then
        self:emit(UNARY_OPS[node.op])
        self:printExpr(node.expr)
    elseif k == "ExprBinary" then
        self:emit("(")
        self:printExpr(node.left)
        self:emit(" " .. (BINARY_OPS[node.op] or "?") .. " ")
        self:printExpr(node.right)
        self:emit(")")
    elseif k == "ExprCall" then
        self:printExpr(node.func)
        self:emit("(")
        for i, a in ipairs(node.args) do
            if i > 1 then self:emit(", ") end
            self:printExpr(a)
        end
        self:emit(")")
    elseif k == "ExprIndexName" then
        self:printExpr(node.expr)
        self:emit((node.op == 58 and ":" or ".") .. node.index)
    elseif k == "ExprIndexExpr" then
        self:printExpr(node.expr)
        self:emit("[")
        self:printExpr(node.index)
        self:emit("]")
    elseif k == "ExprFunction" then
        self:emit("function")
        self:printFuncBody(node)
    elseif k == "ExprTable" then
        self:emit("{")
        for i, item in ipairs(node.items) do
            if i > 1 then self:emit(", ") end
            if item.kind == "Record" then
                self:printExpr(item.key)
                self:emit(" = ")
                self:printExpr(item.value)
            elseif item.kind == "General" then
                self:emit("[")
                self:printExpr(item.key)
                self:emit("] = ")
                self:printExpr(item.value)
            else
                self:printExpr(item.value)
            end
        end
        self:emit("}")
    elseif k == "ExprTypeAssertion" then
        self:printExpr(node.expr)
        self:emit(" :: ")
        self:printType(node.annotation)
    elseif k == "ExprIfElse" then
        self:emit("if ")
        self:printExpr(node.condition)
        self:emit(" then ")
        self:printExpr(node.trueExpr)
        self:emit(" else ")
        self:printExpr(node.falseExpr)
    elseif k == "ExprInterpString" then
        self:emit("`")
        for i, s in ipairs(node.strings) do
            self:emit(s)
            if node.expressions[i] then
                self:emit("{")
                self:printExpr(node.expressions[i])
                self:emit("}")
            end
        end
        self:emit("`")
    else
        self:emit("--[[unhandled expr: " .. tostring(k) .. "]]")
    end
end

function Printer:printFuncBody(node)
    self:emit("(")
    if node.self then
        self:emit("self")
        if #node.args > 0 then self:emit(", ") end
    end
    for i, a in ipairs(node.args) do
        if i > 1 then self:emit(", ") end
        self:emit(a.name)
        if a.annotation then
            self:emit(": ")
            self:printType(a.annotation)
        end
    end
    if node.vararg then
        if #node.args > 0 or node.self then self:emit(", ") end
        self:emit("...")
    end
    self:emit(")\n")
    self.indent += 1
    self:printStat(node.body)
    self.indent -= 1
    self:emitIndent()
    self:emit("end\n")
end

function Printer:printType(node)
    if not node then return end
    local k = node.kind
    if k == "TypeReference" then
        if node.prefix then self:emit(node.prefix .. ".") end
        self:emit(node.name)
    elseif k == "TypeOptional" then
        self:emit("?")
    elseif k == "TypeUnion" then
        for i, t in ipairs(node.types) do
            if i > 1 then self:emit(" | ") end
            self:printType(t)
        end
    elseif k == "TypeIntersection" then
        for i, t in ipairs(node.types) do
            if i > 1 then self:emit(" & ") end
            self:printType(t)
        end
    elseif k == "TypeTable" then
        self:emit("{}")  -- simplified
    elseif k == "TypeFunction" then
        self:emit("(...) -> ...")  -- simplified
    elseif k == "TypeSingletonString" then
        self:emit(string.format("%q", node.value))
    elseif k == "TypeSingletonBool" then
        self:emit(node.value and "true" or "false")
    end
end

return Printer
