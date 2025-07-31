package backend

import "core:container/intrusive/list"

Basic_Block :: struct {
	using link: list.Node,
	instructions: []^Node,
	out: ^Basic_Block,
}

to_basic_blocks :: proc(f: ^Function) {
	bb := new(Basic_Block)

	
}