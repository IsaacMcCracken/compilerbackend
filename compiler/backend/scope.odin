package backend

import vmem "core:mem/virtual"
import "core:fmt"

CTRL_STR :: "@control"

scope_print :: proc(scope_node: ^Node) {
	scope := transmute(^Node_Scope)scope_node.vptr

	fmt.printf("scope @%p [\n", scope_node)
	for key, slot in scope.symbols {
		node := scope_node.inputs[slot]
		fmt.printf("\t%s:\t%04d @%p\n", key, node.vint, node)
	}

	fmt.printf("]\n")

}

scope_lookup_symbol :: proc(f: ^Function, scope_node: ^Node, name: string) -> ^Node {
	recurse :: proc(f: ^Function, scope_node: ^Node, sym_name: string) -> ^Node {
		if scope_node == nil do return nil
		assert(scope_node.kind == .Scope)
		// scope_print(scope_node)
		scope := transmute(^Node_Scope)scope_node.vptr
		slot, ok := scope.symbols[sym_name]

		if !ok do return recurse(f, scope_node.inputs[1], sym_name)


		return scope_node.inputs[slot]
	}

	return recurse(f, scope_node, name)
}

scope_update_symbol :: proc(f: ^Function, scope_node: ^Node, sym_name: string, sym_node: ^Node) -> (old: ^Node) {
	recurse :: proc(f: ^Function, scope_node: ^Node, sym_name: string, sym_node: ^Node) -> ^Node {
		if scope_node == nil do return nil
		assert(scope_node.kind == .Scope)

		scope := transmute(^Node_Scope)scope_node.vptr
		slot, ok := scope.symbols[sym_name]

		if !ok do return recurse(f, scope_node.inputs[1], sym_name, sym_node)

		old := scope_node.inputs[slot]
		set_node_input(f, scope_node, sym_node, slot)
		scope_print(scope_node)
		return old
	}


	old = recurse(f, scope_node, sym_name, sym_node)

	if old == nil {
		scope_add_symbol(f, scope_node, sym_name, sym_node)
	}


	return old
}

scope_add_symbol :: proc(f: ^Function, scope_node: ^Node, sym_name: string, sym_node: ^Node) {
	slot := add_node_input(f, scope_node, sym_node)
	scope := transmute(^Node_Scope)scope_node.vptr
	scope.symbols[sym_name] = slot
}

create_scope_node :: proc(f: ^Function, control: ^Node, prev_scope: ^Node = nil) -> (scope_node: ^Node) {
	node := create_node(f)
	node.kind = .Scope
	scope := new(Node_Scope, vmem.arena_allocator(&f.edge_arena))
	scope.symbols = make(map[string]u16, 11)
	node.vptr = transmute(rawptr)scope
	node_reserve_inputs(f, node, 8)
	set_node_input(f, node, control, 0)
	set_node_input(f, node, prev_scope, 1)	
	return node
}