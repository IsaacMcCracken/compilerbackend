package backend

import "../frontend"
import "x64"
import vmem "core:mem/virtual"
import "core:fmt"

jit_test :: proc(fn: ^frontend.Fn_Decl) {
	fmt.println("STARTING FUNCTION COMPILATION OF", fn.name)
	fmt.println("Size of Node:", size_of(Node))
	e := &x64.Emitter{code = make([dynamic]byte)}
	g := &Function{}
	graph_builder_init(g)

	to_ir_fn_decl(g, fn)

	emit_x64(g, e)

	for b, i in e.code {
		fmt.printf("0x%02X ", b)
	}

	fmt.printf("\n")

	arena := vmem.Arena{}
	err := vmem.arena_init_static(&arena, len(e.code), len(e.code))
	fn_data := make([]byte, len(e.code), vmem.arena_allocator(&arena))
	copy(fn_data, e.code[:])
	vmem.protect(raw_data(fn_data), len(fn_data), {.Execute})

	fn := transmute(proc(x, y: int) -> int)raw_data(fn_data)
	result := fn(3, 4)
	fmt.println("Result:", result)
}