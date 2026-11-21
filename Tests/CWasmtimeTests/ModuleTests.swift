import CWasmtime
import Testing

@Test func compilesWithCraneliftNotPulley() {
    let sandbox = Sandbox()

    #expect(!wasmtime_engine_is_pulley(sandbox.engine))
}

@Test func validatesModules() throws {
    let sandbox = Sandbox()
    let valid = try Sandbox.moduleBytes("arithmetic")
    let invalid: [UInt8] = [0x00, 0x61, 0x73, 0x6d, 0x02]

    #expect(throws: Never.self) { try sandbox.check(wasmtime_module_validate(sandbox.engine, valid, valid.count)) }
    #expect(throws: WasmFailure.self) { try sandbox.check(wasmtime_module_validate(sandbox.engine, invalid, invalid.count)) }
}

@Test func reportsWhyAModuleDoesNotCompile() {
    let sandbox = Sandbox()

    #expect {
        _ = try sandbox.compile([0x00, 0x61, 0x73, 0x6d, 0x02])
    } throws: { error in
        guard case .error(let message) = error as? WasmFailure else { return false }

        return !message.isEmpty
    }
}

@Test func listsImportsAndExports() throws {
    let sandbox = Sandbox()
    let module = try sandbox.compile(Sandbox.moduleBytes("host"))
    defer { wasmtime_module_delete(module) }

    var imports = wasm_importtype_vec_t()
    wasmtime_module_imports(module, &imports)
    defer { wasm_importtype_vec_delete(&imports) }

    var exports = wasm_exporttype_vec_t()
    wasmtime_module_exports(module, &exports)
    defer { wasm_exporttype_vec_delete(&exports) }

    let importNames = UnsafeBufferPointer(start: imports.data, count: imports.size).map { item in
        "\(Sandbox.string(wasm_importtype_module(item).pointee)).\(Sandbox.string(wasm_importtype_name(item).pointee))"
    }
    let exportNames = UnsafeBufferPointer(start: exports.data, count: exports.size).map { item in
        Sandbox.string(wasm_exporttype_name(item).pointee)
    }

    #expect(importNames == ["env.double", "env.offset"])
    #expect(exportNames == ["run"])
}

@Test func serializedModulesLoadBack() throws {
    let sandbox = Sandbox()
    let module = try sandbox.compile(Sandbox.moduleBytes("arithmetic"))
    defer { wasmtime_module_delete(module) }

    var serialized = wasm_byte_vec_t()
    try sandbox.check(wasmtime_module_serialize(module, &serialized))
    defer { wasm_byte_vec_delete(&serialized) }

    var loaded: OpaquePointer?
    let bytes = UnsafeRawPointer(serialized.data!).assumingMemoryBound(to: UInt8.self)
    try sandbox.check(wasmtime_module_deserialize(sandbox.engine, bytes, serialized.size, &loaded))
    defer { wasmtime_module_delete(loaded) }

    var instance = wasmtime_instance_t()
    var trap: OpaquePointer?
    try sandbox.check(wasmtime_instance_new(sandbox.context, loaded, nil, 0, &instance, &trap))

    let add = try sandbox.function("add", of: instance)

    #expect(try sandbox.call(add, [20, 22]) == [42])
}
