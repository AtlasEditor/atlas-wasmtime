import CWasmtime
import Testing

private let pageSize = 65_536

@Test func sharesLinearMemoryWithTheHost() throws {
    let sandbox = Sandbox()
    let instance = try sandbox.instantiate("memory")
    let load = try sandbox.function("load", of: instance)
    let store = try sandbox.function("store", of: instance)
    var memory = try sandbox.export("memory", of: instance).of.memory

    #expect(wasmtime_memory_data_size(sandbox.context, &memory) == pageSize)

    let data = wasmtime_memory_data(sandbox.context, &memory)!
    data[8] = 42

    #expect(try sandbox.call(load, [8]) == [42])

    _ = try sandbox.call(store, [16, 0x0102_0304], results: 0)

    #expect([data[16], data[17], data[18], data[19]] == [4, 3, 2, 1])
}

@Test func trapsOnOutOfBoundsAccess() throws {
    let sandbox = Sandbox()
    let instance = try sandbox.instantiate("memory")
    let load = try sandbox.function("load", of: instance)

    #expect {
        _ = try sandbox.call(load, [Int32(pageSize)])
    } throws: { error in
        guard case .trap(let code, _) = error as? WasmFailure else { return false }

        return code == WASMTIME_TRAP_CODE_MEMORY_OUT_OF_BOUNDS
    }
}

@Test func storeLimiterCapsMemoryGrowth() throws {
    let sandbox = Sandbox()
    wasmtime_store_limiter(sandbox.store, Int64(2 * pageSize), -1, -1, -1, -1)

    let instance = try sandbox.instantiate("memory")
    let grow = try sandbox.function("grow", of: instance)

    #expect(try sandbox.call(grow, [1]) == [1])
    #expect(try sandbox.call(grow, [1]) == [-1])
}

@Test func hostGrowsMemory() throws {
    let sandbox = Sandbox()
    let instance = try sandbox.instantiate("memory")
    var memory = try sandbox.export("memory", of: instance).of.memory
    var previous: UInt64 = 0

    try sandbox.check(wasmtime_memory_grow(sandbox.context, &memory, 3, &previous))

    #expect(previous == 1)
    #expect(wasmtime_memory_size(sandbox.context, &memory) == 4)
}

@Test func tablesHoldFunctionReferences() throws {
    let sandbox = Sandbox()
    let instance = try sandbox.instantiate("arithmetic")
    let add = try sandbox.function("add", of: instance)

    let type = wasm_tabletype_new(wasm_valtype_new(UInt8(WASM_FUNCREF.rawValue)), [wasm_limits_t(min: 1, max: 4)])
    defer { wasm_tabletype_delete(type) }

    var empty = wasmtime_val_t()
    empty.kind = wasmtime_valkind_t(WASMTIME_FUNCREF)

    var table = wasmtime_table_t()
    try sandbox.check(wasmtime_table_new(sandbox.context, type, &empty, &table))

    var previous: UInt64 = 0
    try sandbox.check(wasmtime_table_grow(sandbox.context, &table, 1, &empty, &previous))

    var reference = empty
    reference.of.funcref = add
    try sandbox.check(wasmtime_table_set(sandbox.context, &table, 1, &reference))

    var stored = wasmtime_val_t()
    let isInBounds = wasmtime_table_get(sandbox.context, &table, 1, &stored)

    #expect(previous == 1)
    #expect(wasmtime_table_size(sandbox.context, &table) == 2)
    #expect(isInBounds)
    #expect(try sandbox.call(stored.of.funcref, [40, 2]) == [42])
}
