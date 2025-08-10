package backend
import "base:runtime"
import "core:c"
import vmem "core:mem/virtual"
import "core:mem"
import "core:slice"


/*
	Design Decisions
	================

	We leak memory
	
*/

Node_Type_Kind :: enum u8 {
	Void,
	Bool,
	I64,
	Ptr,
	Control,
	Memory,
	Tuple,
}

Node_Type :: bit_field u8 {
	kind: Node_Type_Kind | 4,
	// elem: u8 | 4,
}

Node_Kind :: enum u16 {
	Invalid,

	// control flow
	Start,
	Stop,
	Return, // Return(Prev_Control, Return Expr)
	If,		// If(Prev_Control, Condition)
	Region,
	// values
	Const,
	Phi,
	Tuple,
	Proj,
	// Helpers
	Scope,	// Scope(control, prev_scope, ...Symbols)
	// math
	Add, // Add(lhs, rhs) 
	Sub, // Sub(lhs, rhs)
	Mul, // Mul(lhs, rhs)
	Div, // Div(lhs, rhs)
	// logic
	Equals,
	Less_Than,
	Less_Than_Equal,
	Greater_Than,
	Greater_Than_Equal,

}

Node_User :: bit_field uintptr {
	ptr: uintptr | 48,
	slot: u16 | 16,
}

Node_Key :: struct {
	value: i64,
	inputs: []^Node,
}

Node :: struct {
	inputs: [^]^Node,
	users: [^]Node_User,
	gvn: u32,
	using value: struct #raw_union { // the value depends on the node kind.
		vb32: b32,
		vint: i64,
		vf32: f32,
		vf64: f64,
		vptr: rawptr,
	},
	kind: Node_Kind,
	inputlen, userlen: u16,
	inputcap, usercap: u16,
	type: Node_Type,
}


Node_Scope :: struct {
	symbols: map[string]u16
}

@(private="file") Free_Node :: struct #raw_union {
	next: ^Free_Node,
	node: Node
}

node_hash_to_key :: proc(node: ^Node) -> u64 {
	return 1
}

very_hacky_key_creation :: proc(node: ^Node) -> string {
	bytes := make([]byte, size_of(i64) + size_of(Node_Kind) + size_of(^Node) * int(node.inputlen), context.temp_allocator)
	bi64 := transmute([size_of(i64)]byte)node.vint
	for b, i in bi64 do bytes[i] = b
	offset := size_of(bi64)
	bkind := transmute([size_of(Node_Kind)]byte)node.kind
	for b, i in bkind do bytes[i + offset] = b
	offset = size_of(bi64) + size_of(bkind)
	binputs := slice.reinterpret([]byte, node.inputs[:node.inputlen])
	for b, i in binputs do bytes[i + offset] = b 
	return string(bytes)
}

Function :: struct {
	node_arena: vmem.Arena,
	edge_arena: vmem.Arena,
	used_space, dead_space: int, // used to trigger a gc step
	node_free_list: ^Free_Node,
	nmap: Node_Map,
	scheduled: [dynamic]^Node,
	start, stop, scope: ^Node
}


graph_builder_init :: proc(f: ^Function) {
	
	err := vmem.arena_init_growing(&f.node_arena)
	if err != nil {
		return
	}

	err = vmem.arena_init_growing(&f.edge_arena)
	if err != nil {
		return
	}


	f.nmap, err = make_node_map(1<<8)
	if err != nil {
		return
	}

}



node_reserve_inputs :: proc(f: ^Function, node: ^Node, cap: u16) {
	assert(node.inputs == nil)
	context.allocator = vmem.arena_allocator(&f.edge_arena)
	node.inputs = make([^]^Node, cap)
	node.inputcap = cap
}

node_reserve_users :: proc(f: ^Function, node: ^Node, cap: u16) {
	assert(node.users == nil)
	context.allocator = vmem.arena_allocator(&f.edge_arena)
	node.users = make([^]Node_User, cap)
	node.usercap = cap
}

create_fn_arg_node :: proc(f: ^Function, name: string, i: int) -> ^Node {
	node := create_proj_node(f, i, f.start)
	scope_update_symbol(f, f.scope,	name, node)
	return node
}

create_if_node :: proc(f: ^Function, prev_control, condition: ^Node) -> (nif, ntrue, nfalse: ^Node) {
	nif = &Node{
		kind = .If,
		type = {kind = .Control}
	}

	node_reserve_inputs(f, nif, 2)
	node_reserve_users(f, nif, 3)

	set_node_input(f, nif, prev_control, 0)
	set_node_input(f, nif, condition, 1)

	nif = create_node(f, nif)

	ntrue = create_proj_node(f, 0, nif)
	nfalse = create_proj_node(f, 1, nif)


	return
}



create_return_node :: proc(f: ^Function, prev_control, expr: ^Node) -> ^Node {
	node := &Node{
		kind = .Return,
		type = {kind = .Control}
	}

	node_reserve_inputs(f, node, 2)
	set_node_input(f, node, prev_control, 0)
	set_node_input(f, node, expr, 1)

	node = create_node(f, node)
	
	add_node_input(f, f.stop, node)
	return node
}

create_region_node :: proc(f: ^Function, controls: ..^Node) -> (node: ^Node) {
	node = &Node{
		kind = .Region,
		type = {kind = .Control}
	}
	node_reserve_inputs(f, node, u16(len(controls)))

	for c in controls {
		add_node_input(f, node, c)
	}

	node = create_node(f, node)
	return node
}

create_region_from_scopes :: proc(f: ^Function, scope_a, scope_b: ^Node) -> (region:  ^Node) {
	assert(scope_a.inputs[0] == scope_b.inputs[0])
	assert(scope_a.kind == .Scope && scope_b.kind == .Scope)
	/*
		1. for all symbols in scope a if its in scope b create a phi and update the symbol
		in parent scope

		2.    
		r
	*/
	return
}

create_proj_node :: proc(f: ^Function, i: int, input: ^Node) -> ^Node {
	node := &Node{
		kind = .Proj,
	}
	node.kind = .Proj
	node.vint = i64(i)
	node_reserve_inputs(f, node, 1)
	set_node_input(f, node, input, 0)
	// fix this
	#partial switch input.kind {
		case .If: node.type.kind = .Control
		case .Start: node.type.kind = .I64
	}

	node = create_node(f, node)
	return node
}

create_phi :: proc(f: ^Function, name: string, scope, region: ^Node, inputs: ..^Node) -> ^Node {
	node := &Node{
		kind = .Phi
	}
	node_reserve_inputs(f, node, 1 + u16(len(inputs)))
	set_node_input(f, node, region, 0)

	type := Node_Type{}
	for input in inputs {
		if type.kind == .Void do type = input.type
		else do assert(input.type == type)
		add_node_input(f, node, input)
	}

	node = create_node(f, node)
	scope_update_symbol(f, scope, name, node)
	return node
}

create_const_int_node :: proc(f: ^Function, v: i64) -> ^Node {
	node := &Node {
		kind = .Const,
		type = {kind = .I64},
		vint = v,
	}
	node_reserve_inputs(f, node, 1)
	set_node_input(f, node, f.start, 0)

	node = create_node(f, node)
	return node
}

create_start_node :: proc(f: ^Function) -> ^Node {
	node := &Node{
		kind = .Start,
		type = {kind = .Control}
	}

	node = create_node(f, node)
	return node
}

create_stop_node :: proc(f: ^Function) -> ^Node {
	node := &Node{
		kind = .Stop,
		type = {kind = .Control}
	}

	node = create_node(f, node)
	return node
}

// create_const_bool_node :: proc(f: ^Function, v: b32) {

// }

is_if_projection :: proc(n: ^Node) -> (ok :bool) {
	return n.kind == .Proj && n.inputs[0].kind == .If && n.vint < 2
}

create_bin_op_node :: proc(f: ^Function, op: Node_Kind, lhs, rhs: ^Node) -> ^Node {
	node := &Node{
		kind = op
	}
	node_reserve_inputs(f, node, 2)
	set_node_input(f, node, lhs, 0)
	set_node_input(f, node, rhs, 1)

	node = create_node(f, node)
	node = peephole(f, node)
	return node 
}

create_node :: proc(f: ^Function, n: ^Node) -> (node: ^Node) {
	if n != nil {
		ok: bool
		node, ok = node_map_lookup(f, n)
		if ok do return node
	}

	context.allocator = vmem.arena_allocator(&f.node_arena)
	if f.node_free_list == nil {
		node = new(Node)
	} else {
		node = &f.node_free_list.node
		f.node_free_list = f.node_free_list.next
	
	}
	
	mem.copy(node, n, size_of(Node))
	node_map_insert(f, node)

	return node
}

destroy_node :: proc(f: ^Function, n: ^Node) {
	assert(n.userlen == 0)
	inputs := get_node_inputs
	// for input, idx in .
}

unwrap_user :: proc(user: Node_User) -> (node: ^Node, slot: u16) {
	return transmute(^Node)user.ptr, user.slot
}


get_node_inputs :: proc(n: ^Node) -> []^Node {
	return n.inputs[:n.inputlen]
}

get_node_users :: proc(n: ^Node) -> []Node_User {
	return n.users[:n.userlen]
}

// we want to remove the user from the input
// delete_node_input_user :: proc(f: ^Function, user, input: ^Node) -> (ok: bool) {
// 	wusers := get_node_users(input) 
// 	for wuser, idx in wusers {
// 		ptr, slot := unwrap_user(wuser)
// 		if ptr == user {
// 			remove_user(input, wuser)
// 			return true
// 		}
// 	}
// }

set_node_input :: proc(f: ^Function, user, input: ^Node, slot: u16) {
	assert(slot < user.inputcap) // will give us runtime error
	old_input := user.inputs[slot]
	if old_input != nil {

	}
	user.inputs[slot] = input
	user.inputlen = max(user.inputlen, slot+1)
	if input != nil do add_node_user(f, user, input, slot)
}

add_node_input :: proc(f: ^Function, user, input: ^Node) -> (slot: u16) {
	if user.inputs == nil {
		node_reserve_inputs(f, user, 4)
	}
	if user.inputlen >= user.inputcap {
		new_cap := 2*int(user.inputcap)
		if new_cap >= int(max(u16)) {
			panic("Fudge Nuggets")
		}

		inputs := make([^]^Node, new_cap)
		copy(inputs[:user.inputlen], user.inputs[:user.inputlen])

		user.inputs = inputs
		user.inputcap = u16(new_cap)
	}

	slot = user.inputlen	
	user.inputs[slot] = input

	if input != nil do add_node_user(f, user, input, slot)

	user.inputlen += 1


	return slot
}



remove_input :: proc(user: ^Node, input_idx: u16) {
	raw_input_array := runtime.Raw_Dynamic_Array{
		data = transmute(rawptr)user.inputs,
		len = int(user.inputlen),
		cap = int(user.inputcap),
	}

	input_array := transmute([dynamic]^Node)raw_input_array
	ordered_remove(&input_array, input_idx)

	raw_input_array = transmute(runtime.Raw_Dynamic_Array)input_array

	user.inputcap = u16(raw_input_array.cap)
	user.inputlen = u16(raw_input_array.len)
	user.inputs = transmute([^]^Node)raw_input_array.data
}

remove_user :: proc(node, user: ^Node) {
	raw_user_array := runtime.Raw_Dynamic_Array{
		data = transmute(rawptr)node.users,
		len = int(user.userlen),
		cap = int(user.usercap),
	}

	user_array := transmute([dynamic]Node_User)raw_user_array

	slot: int
	for n, i in user_array {
		unode, _ := unwrap_user(n)
		if unode == user do slot = i
	}

	unordered_remove(&user_array, slot)

	raw_user_array = transmute(runtime.Raw_Dynamic_Array)user_array

	node.userlen = u16(raw_user_array.len)
	node.usercap = u16(raw_user_array.cap)
	node.users = transmute([^]Node_User)raw_user_array.data
}

add_node_user :: proc(f: ^Function, user, input: ^Node, slot: u16, reserve:u16=4) {
	context.allocator = vmem.arena_allocator(&f.edge_arena)
	if input.users == nil {
		input.users = make([^]Node_User, reserve)
		input.usercap = reserve
	}
	if input.userlen >= input.usercap {
		new_cap := 2 * int(input.usercap)
		if new_cap >= int(max(u16)) {
			panic("Too many users for one node")
		}

		users := make([^]Node_User, new_cap)
		copy(users[:input.userlen], input.users[:input.userlen])

		input.users = users
		input.usercap = u16(new_cap)
	}

	input.users[input.userlen] = Node_User{
		ptr = transmute(uintptr)user,
		slot = slot,
	}

	input.userlen += 1
}

