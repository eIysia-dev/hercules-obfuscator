local config = require("config")

local StringEncoder           = require("modules/string_encoder")
local VariableRenamer         = require("modules/variable_renamer")
local ControlFlowObfuscator   = require("modules/control_flow_obfuscator")
local GarbageCodeInserter     = require("modules/garbage_code_inserter")
local OpaquePredicateInjector = require("modules/opaque_predicate_injector")
local FunctionInliner         = require("modules/function_inliner")
local DynamicCodeGenerator    = require("modules/dynamic_code_generator")
local BytecodeEncoder         = require("modules/bytecode_encoder")
local Watermarker             = require("modules/watermark")
local Compressor              = require("modules/compressor")
local StringToExpressions     = require("modules/StringToExpressions")
local WrapInFunction          = require("modules/WrapInFunction")
local VirtualMachinery        = require("modules/VMGenerator")
local AntiTamper              = require("modules/antitamper")

local Pipeline = {}

function Pipeline.process(code)
    -- 1. String encoding (caesar on string literals before any structural changes)
    if config.get("settings.string_encoding.enabled") then
        code = StringEncoder.process(code)
    end

    -- 2. Function inlining (do before renaming so names still match)
    if config.get("settings.function_inlining.enabled") then
        code = FunctionInliner.process(code)
    end

    -- 3. First garbage pass (prefix/suffix)
    if config.get("settings.garbage_code.enabled") then
        local garbage_blocks = config.get("settings.garbage_code.garbage_blocks")
        code = GarbageCodeInserter.process(code, garbage_blocks)
    end

    -- 4. Opaque predicates
    if config.get("settings.opaque_predicates.enabled") then
        code = OpaquePredicateInjector.process(code)
    end

    -- 5. Bytecode encoding (must happen before VM, after source transforms)
    if config.get("settings.bytecode_encoding.enabled") then
        code = BytecodeEncoder.process(code)
    end

    -- 6. VM (compiles to custom bytecode — do before StringToExpressions
    --    so the compiler sees normal Lua, not expression soup)
    if config.get("settings.VirtualMachine.enabled") then
        code = VirtualMachinery.process(code)
    end

    -- 7. StringToExpressions AFTER VM so VM compiler isn't confused
    if config.get("settings.StringToExpressions.enabled") then
        local min_length = config.get("settings.StringToExpressions.min_number_length")
        local max_length = config.get("settings.StringToExpressions.max_number_length")
        code = StringToExpressions.process(code, min_length, max_length)
    end

    -- 8. Anti-tamper wrapper
    if config.get("settings.antitamper.enabled") then
        code = AntiTamper.process(code)
    end

    -- 9. Control flow obfuscation
    if config.get("settings.control_flow.enabled") then
        local max_fake_blocks = config.get("settings.control_flow.max_fake_blocks")
        code = ControlFlowObfuscator.process(code, max_fake_blocks)
    end

    -- 10. Second garbage pass (scatter between lines for deeper interleaving)
    if config.get("settings.garbage_code.enabled") then
        local garbage_blocks = config.get("settings.garbage_code.garbage_blocks")
        code = GarbageCodeInserter.scatter(code, math.max(1, math.floor(garbage_blocks / 2)))
    end

    -- 11. Variable renaming (last source-level step before compression)
    if config.get("settings.variable_renaming.enabled") then
        local min_length = config.get("settings.variable_renaming.min_name_length")
        local max_length = config.get("settings.variable_renaming.max_name_length")
        code = VariableRenamer.process(code, { min_length = min_length, max_length = max_length })
    end

    -- 12. Compress (whitespace/comment removal — do last so it doesn't
    --     strip things other passes still need)
    if config.get("settings.compressor.enabled") then
        code = Compressor.process(code)
    end

    -- 13. Wrap in function (outermost shell)
    if config.get("settings.WrapInFunction.enabled") then
        code = WrapInFunction.process(code)
    end

    -- 14. Watermark
    if config.get("settings.watermark_enabled") then
        code = Watermarker.process(code)
    end

    return code
end

return Pipeline
