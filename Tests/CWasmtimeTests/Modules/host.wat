(module
  (import "env" "double" (func $double (param i32) (result i32)))
  (import "env" "offset" (global $offset (mut i32)))

  (func (export "run") (param i32) (result i32)
    local.get 0
    call $double
    global.get $offset
    i32.add))
