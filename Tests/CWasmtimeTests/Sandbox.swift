import CWasmtime
import Foundation
import Testing

enum WasmFailure: Error, Equatable {
    case error(String)
    case trap(code: wasmtime_trap_code_enum?, message: String)
}

/// An engine and a store for one test, with helpers that turn C results into Swift errors.
final class Sandbox {
    let engine: OpaquePointer
    let store: OpaquePointer
    let context: OpaquePointer

    init(configure: (OpaquePointer) -> Void = { _ in }) {
        let config = wasm_config_new()!
        configure(config)

        engine = wasm_engine_new_with_config(config)
        store = wasmtime_store_new(engine, nil, nil)
        context = wasmtime_store_context(store)
    }

    deinit {
        wasmtime_store_delete(store)
        wasm_engine_delete(engine)
    }

    static func moduleBytes(_ name: String) throws -> [UInt8] {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "wasm"))

        return try [UInt8](Data(contentsOf: url))
    }

    func compile(_ bytes: [UInt8]) throws(WasmFailure) -> OpaquePointer {
        var module: OpaquePointer?
        try check(wasmtime_module_new(engine, bytes, bytes.count, &module))

        return module!
    }

    func instantiate(_ name: String, imports: [wasmtime_extern_t] = []) throws -> wasmtime_instance_t {
        let module = try compile(Self.moduleBytes(name))
        defer { wasmtime_module_delete(module) }

        var instance = wasmtime_instance_t()
        var trap: OpaquePointer?
        try check(wasmtime_instance_new(context, module, imports, imports.count, &instance, &trap))
        try check(trap: trap)

        return instance
    }

    func export(_ name: String, of instance: wasmtime_instance_t) throws -> wasmtime_extern_t {
        var instance = instance
        var item = wasmtime_extern_t()
        let isFound = wasmtime_instance_export_get(context, &instance, name, name.utf8.count, &item)

        return try #require(isFound ? item : nil, "no export \(name)")
    }

    func function(_ name: String, of instance: wasmtime_instance_t) throws -> wasmtime_func_t {
        let item = try export(name, of: instance)
        try #require(item.kind == WASMTIME_EXTERN_FUNC)

        return item.of.func
    }

    func call(_ function: wasmtime_func_t, _ arguments: [Int32], results count: Int = 1) throws(WasmFailure) -> [Int32] {
        var function = function
        let values = arguments.map(Self.i32)
        var results = [wasmtime_val_t](repeating: wasmtime_val_t(), count: count)
        var trap: OpaquePointer?

        try check(wasmtime_func_call(context, &function, values, values.count, &results, count, &trap))
        try check(trap: trap)

        return results.map(\.of.i32)
    }

    static func i32(_ value: Int32) -> wasmtime_val_t {
        var result = wasmtime_val_t()
        result.kind = wasmtime_valkind_t(WASMTIME_I32)
        result.of.i32 = value

        return result
    }

    func check(_ error: OpaquePointer?) throws(WasmFailure) {
        guard let error else { return }
        defer { wasmtime_error_delete(error) }

        var message = wasm_byte_vec_t()
        wasmtime_error_message(error, &message)
        defer { wasm_byte_vec_delete(&message) }

        throw .error(Self.string(message))
    }

    func check(trap: OpaquePointer?) throws(WasmFailure) {
        guard let trap else { return }
        defer { wasm_trap_delete(trap) }

        var message = wasm_byte_vec_t()
        wasm_trap_message(trap, &message)
        defer { wasm_byte_vec_delete(&message) }

        var code = wasmtime_trap_code_t()
        let hasCode = wasmtime_trap_code(trap, &code)
        let trapCode = hasCode ? wasmtime_trap_code_enum(rawValue: .init(code)) : nil

        throw .trap(code: trapCode, message: Self.string(message))
    }

    static func string(_ bytes: wasm_byte_vec_t) -> String {
        let buffer = UnsafeRawBufferPointer(start: bytes.data, count: bytes.size)

        return String(decoding: buffer, as: UTF8.self).trimmingCharacters(in: ["\0"])
    }
}
