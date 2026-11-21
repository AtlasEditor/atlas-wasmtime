import CWasmtime
import Testing

@Test func callsAnExportedFunction() throws {
    let sandbox = Sandbox()
    let instance = try sandbox.instantiate("arithmetic")
    let add = try sandbox.function("add", of: instance)

    #expect(try sandbox.call(add, [2, 40]) == [42])
    #expect(try sandbox.call(add, [Int32.max, 1]) == [Int32.min])
}

@Test func callsAnExportedFunctionUnchecked() throws {
    let sandbox = Sandbox()
    let instance = try sandbox.instantiate("arithmetic")
    var add = try sandbox.function("add", of: instance)
    var values = [wasmtime_val_raw_t(i32: 2), wasmtime_val_raw_t(i32: 40)]
    var trap: OpaquePointer?

    try sandbox.check(wasmtime_func_call_unchecked(sandbox.context, &add, &values, values.count, &trap))
    try sandbox.check(trap: trap)

    #expect(values[0].i32 == 42)
}

@Test func rejectsArgumentsOfTheWrongType() throws {
    let sandbox = Sandbox()
    let instance = try sandbox.instantiate("arithmetic")
    var add = try sandbox.function("add", of: instance)

    var wrong = wasmtime_val_t()
    wrong.kind = wasmtime_valkind_t(WASMTIME_I64)
    wrong.of.i64 = 1

    let arguments = [wrong, wrong]
    var result = wasmtime_val_t()
    var trap: OpaquePointer?

    #expect(throws: WasmFailure.self) {
        try sandbox.check(wasmtime_func_call(sandbox.context, &add, arguments, 2, &result, 1, &trap))
    }
}

/// Builds the imports of host.wat: `double` doubles its argument, and `offset` is a mutable global.
func hostImports(_ sandbox: Sandbox, offset: Int32, double: wasmtime_func_callback_t) -> [wasmtime_extern_t] {
    let type = wasm_functype_new_1_1(wasm_valtype_new(UInt8(WASM_I32.rawValue)), wasm_valtype_new(UInt8(WASM_I32.rawValue)))
    defer { wasm_functype_delete(type) }

    var function = wasmtime_extern_t()
    function.kind = wasmtime_extern_kind_t(WASMTIME_EXTERN_FUNC)
    wasmtime_func_new(sandbox.context, type, double, nil, nil, &function.of.func)

    let globalType = wasm_globaltype_new(wasm_valtype_new(UInt8(WASM_I32.rawValue)), UInt8(WASM_VAR.rawValue))
    defer { wasm_globaltype_delete(globalType) }

    var global = wasmtime_extern_t()
    global.kind = wasmtime_extern_kind_t(WASMTIME_EXTERN_GLOBAL)
    var value = Sandbox.i32(offset)
    _ = wasmtime_global_new(sandbox.context, globalType, &value, &global.of.global)

    return [function, global]
}

@Test func callsBackIntoTheHost() throws {
    let sandbox = Sandbox()
    let imports = hostImports(sandbox, offset: 2) { _, _, arguments, _, results, _ in
        results![0] = Sandbox.i32(arguments![0].of.i32 * 2)

        return nil
    }
    let instance = try sandbox.instantiate("host", imports: imports)
    let run = try sandbox.function("run", of: instance)

    #expect(try sandbox.call(run, [20]) == [42])
}

@Test func passesAHostTrapToTheCaller() throws {
    let sandbox = Sandbox()
    let imports = hostImports(sandbox, offset: 0) { _, _, _, _, _, _ in
        let message = "host refused"

        return wasmtime_trap_new(message, message.utf8.count)
    }
    let instance = try sandbox.instantiate("host", imports: imports)
    let run = try sandbox.function("run", of: instance)

    #expect {
        _ = try sandbox.call(run, [1])
    } throws: { error in
        // wasmtime returns a trap raised by the host as an error with the trap message.
        switch error as? WasmFailure {
        case .error(let message), .trap(_, let message): message.contains("host refused")
        case nil: false
        }
    }
}

@Test func readsAndWritesAGlobalFromTheHost() throws {
    let sandbox = Sandbox()
    let imports = hostImports(sandbox, offset: 0) { _, _, arguments, _, results, _ in
        results![0] = arguments![0]

        return nil
    }
    let instance = try sandbox.instantiate("host", imports: imports)
    let run = try sandbox.function("run", of: instance)
    var offset = imports[1].of.global
    var value = Sandbox.i32(100)

    try sandbox.check(wasmtime_global_set(sandbox.context, &offset, &value))

    var read = wasmtime_val_t()
    wasmtime_global_get(sandbox.context, &offset, &read)

    #expect(read.of.i32 == 100)
    #expect(try sandbox.call(run, [1]) == [101])
}
