local Transformer = {}

-- Walk and optionally replace nodes
function Transformer.walk(node, visitor)
    if type(node) ~= "table" or not node.kind then return node end

    -- Call visitor before descending
    if visitor.before then
        local result = visitor.before(node)
        if result ~= nil then return result end
    end

    -- Recurse into children based on kind
    local k = node.kind

    if k == "StatBlock" then
        for i, s in ipairs(node.body) do
            node.body[i] = Transformer.walk(s, visitor)
        end
    elseif k == "StatLocal" then
        for i, v in ipairs(node.values) do
            node.values[i] = Transformer.walk(v, visitor)
        end
    elseif k == "StatAssign" then
        for i, v in ipairs(node.vars) do
            node.vars[i] = Transformer.walk(v, visitor)
        end
        for i, v in ipairs(node.values) do
            node.values[i] = Transformer.walk(v, visitor)
        end
    elseif k == "StatExpr" then
        node.expr = Transformer.walk(node.expr, visitor)
    elseif k == "StatReturn" then
        for i, v in ipairs(node.list) do
            node.list[i] = Transformer.walk(v, visitor)
        end
    elseif k == "StatIf" then
        node.condition = Transformer.walk(node.condition, visitor)
        node.thenbody = Transformer.walk(node.thenbody, visitor)
        if node.elsebody then
            node.elsebody = Transformer.walk(node.elsebody, visitor)
        end
    elseif k == "StatWhile" then
        node.condition = Transformer.walk(node.condition, visitor)
        node.body = Transformer.walk(node.body, visitor)
    elseif k == "StatRepeat" then
        node.body = Transformer.walk(node.body, visitor)
        node.condition = Transformer.walk(node.condition, visitor)
    elseif k == "StatFor" then
        node.from = Transformer.walk(node.from, visitor)
        node.to = Transformer.walk(node.to, visitor)
        if node.step then node.step = Transformer.walk(node.step, visitor) end
        node.body = Transformer.walk(node.body, visitor)
    elseif k == "StatForIn" then
        for i, v in ipairs(node.values) do
            node.values[i] = Transformer.walk(v, visitor)
        end
        node.body = Transformer.walk(node.body, visitor)
    elseif k == "StatFunction" then
        node.func = Transformer.walk(node.func, visitor)
    elseif k == "StatLocalFunction" then
        node.func = Transformer.walk(node.func, visitor)
    elseif k == "ExprCall" then
        node.func = Transformer.walk(node.func, visitor)
        for i, a in ipairs(node.args) do
            node.args[i] = Transformer.walk(a, visitor)
        end
    elseif k == "ExprBinary" then
        node.left = Transformer.walk(node.left, visitor)
        node.right = Transformer.walk(node.right, visitor)
    elseif k == "ExprUnary" then
        node.expr = Transformer.walk(node.expr, visitor)
    elseif k == "ExprGroup" then
        node.expr = Transformer.walk(node.expr, visitor)
    elseif k == "ExprIndexExpr" then
        node.expr = Transformer.walk(node.expr, visitor)
        node.index = Transformer.walk(node.index, visitor)
    elseif k == "ExprIndexName" then
        node.expr = Transformer.walk(node.expr, visitor)
    elseif k == "ExprFunction" then
        node.body = Transformer.walk(node.body, visitor)
    elseif k == "ExprTable" then
        for i, item in ipairs(node.items) do
            if item.key then item.key = Transformer.walk(item.key, visitor) end
            item.value = Transformer.walk(item.value, visitor)
        end
    elseif k == "ExprTypeAssertion" then
        node.expr = Transformer.walk(node.expr, visitor)
    elseif k == "ExprIfElse" then
        node.condition = Transformer.walk(node.condition, visitor)
        node.trueExpr = Transformer.walk(node.trueExpr, visitor)
        node.falseExpr = Transformer.walk(node.falseExpr, visitor)
    end

    -- Call visitor after descending
    if visitor.after then
        local result = visitor.after(node)
        if result ~= nil then return result end
    end

    return node
end

return Transformer
