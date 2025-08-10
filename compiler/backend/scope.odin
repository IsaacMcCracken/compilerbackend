package backend

import vmem "core:mem/virtual"
import "core:fmt"

CTRL_STR :: "@control"

scope_print :: proc(scope_node: ^Node) {
	scope := transmute(^Node_Scope)scope_node.vptr

	fmt.printf("scope @%p [\n", scope_node)
	for key, slot in scope.symbols {
		node := scope_node.inputs[slot]
		fmt.printf("\t%s: %v %v\t= %04d @%p\n", key, node.kind, node.type.kind, node.vint, node)
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

scope_has_symbol :: proc(scope_node: ^Node, name: string) -> (node: ^Node, ok: bool) {
	assert(scope_node.kind == .Scope)

	scope := transmute(^Node_Scope)scope_node.vptr
	slot, lok := scope.symbols[name]
	
	if lok do return scope_node.inputs[slot], true

	return	
}

scope_update_symbol :: proc(f: ^Function, scope_node: ^Node, sym_name: string, sym_node: ^Node) -> (old: ^Node) {
	assert(scope_node.kind == .Scope)

	scope := transmute(^Node_Scope)scope_node.vptr
	slot, ok := scope.symbols[sym_name]

	if ok {
		old = scope_node.inputs[slot]
	}

	set_node_input(f, scope_node, sym_node, slot)
	scope_add_symbol(f, scope_node, sym_name, sym_node)
	 
	scope_print(scope_node)

	return old
}

scope_add_symbol :: proc(f: ^Function, scope_node: ^Node, sym_name: string, sym_node: ^Node) {
	slot := add_node_input(f, scope_node, sym_node)
	scope := transmute(^Node_Scope)scope_node.vptr
	scope.symbols[sym_name] = slot
}

get_scope_from_node :: proc(n: ^Node) -> (scope: ^Node, ok: bool) {
	users := get_node_users(n)
	for user in users {
		unode, slot := unwrap_user(user) 
		if unode != nil {
			if unode.kind == .Scope do return unode, true
		}
	}

	return
}

create_scope_node :: proc(f: ^Function, control: ^Node, prev_scope: ^Node = nil) -> (scope_node: ^Node) {
	scope := new(Node_Scope, vmem.arena_allocator(&f.edge_arena))
	scope.symbols = make(map[string]u16, 11)

	node := &Node{
		kind = .Scope,
		vptr = scope
	}

	node_reserve_inputs(f, node, 8)
	set_node_input(f, node, control, 0)
	set_node_input(f, node, prev_scope, 1)	

	node = create_node(f, node)
	return node
}