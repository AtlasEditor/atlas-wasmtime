import CWasmtime
import Testing

@Test func trapsOnUnreachable() throws {
    let sandbox = Sandbox()
    let instance = try sandbox.instantiate("arithmetic")
    let crash = try sandbox.function("crash", of: instance)

    #expect {
        _ = try sandbox.call(crash, [], results: 0)
    } throws: { error in
        guard case .trap(let code, _) = error as? WasmFailure else { return false }

        return code == WASMTIME_TRAP_CODE_UNREACHABLE_CODE_REACHED
    }
}

@Test func epochDeadlineInterruptsALoop() throws {
    let sandbox = Sandbox { config in wasmtime_config_epoch_interruption_set(config, true) }
    let instance = try sandbox.instantiate("arithmetic")
    let add = try sandbox.function("add", of: instance)
    let spin = try sandbox.function("spin", of: instance)

    wasmtime_context_set_epoch_deadline(sandbox.context, 1)

    #expect(try sandbox.call(add, [1, 1]) == [2])

    wasmtime_engine_increment_epoch(sandbox.engine)

    #expect {
        _ = try sandbox.call(spin, [], results: 0)
    } throws: { error in
        guard case .trap(let code, _) = error as? WasmFailure else { return false }

        return code == WASMTIME_TRAP_CODE_INTERRUPT
    }
}

@Test func fuelStopsALoop() throws {
    let sandbox = Sandbox { config in wasmtime_config_consume_fuel_set(config, true) }
    let instance = try sandbox.instantiate("arithmetic")
    let spin = try sandbox.function("spin", of: instance)

    try sandbox.check(wasmtime_context_set_fuel(sandbox.context, 10_000))

    #expect {
        _ = try sandbox.call(spin, [], results: 0)
    } throws: { error in
        guard case .trap(let code, _) = error as? WasmFailure else { return false }

        return code == WASMTIME_TRAP_CODE_OUT_OF_FUEL
    }
}
