package compiler 


import os "core:os/os2"
import "core:fmt"
import vmem "core:mem/virtual"
import "../format"
import "backend"
import "frontend"
import "core:strings"
import "core:slice"

main :: proc() {

	fname := os.args[1]
	arena: vmem.Arena
	erm := vmem.arena_init_static(&arena)
	context.allocator = vmem.arena_allocator(&arena)

	src, err := os.read_entire_file(fname, context.allocator)

	if err != nil {
		fmt.println("could not read file:", fname)
		return
	}

	if len(src) >= int(max(u32)) {
		fmt.println("too big.")
		return
	}

	tokens := make([dynamic]format.Token)
	format.tokenize(&tokens, src)
	p := &format.Parser{
		tokens = tokens[:],
		src = src,
	}
	format.parse(p)

	c := &frontend.Converter {
		p = p^
	}

	decls := frontend.convert_tree_to_ast(c)
	square := decls[0].(^frontend.Fn_Decl)
	fmt.println(square, square.body.stmts)
	b := strings.builder_init(&{})
	backend.to_c_fn_decl(square, b)
	fmt.println(strings.to_string(b^))
	backend.jit_test(square)
	// backend.to_c_fn_decl(decls[0].(^Fn_Decl))


}