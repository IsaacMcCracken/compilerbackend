package backend
import "base:runtime"
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
	Return, // Return(Prev_Control, Return Expr)
	If,		// If(Prev_Control, Condition)
	// values
	Const,
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
	gvn_lookup: map[u64]^Node,
	scheduled: [dynamic]^Node,
	start, scope: ^Node
}

graph_builder_init :: proc(f: ^Function) {

	err := vmem.arena_init_growing(&f.node_arena)
	if err != nil {
		return
	}

	err = vmem.arena_init_growing(&f.edge_arena)
}



node_reserve_inputs :: proc(f: ^Function, node: ^Node, cap: u16) {
	assert(node.inputs == nil)
	context.allocator = vmem.arena_allocator(&f.edge_arena)
	node.inputs = make([^]^Node, cap)
	node.inputcap = cap
}


create_fn_arg_node :: proc(f: ^Function, name: string, i: int) -> ^Node {
	node := create_proj_node(f, i, f.start)
	scope_update_symbol(f, f.scope,	name, node)
	return node
}


create_return_node :: proc(f: ^Function, prev_control, expr: ^Node) -> ^Node {
	node := create_node(f)
	node.kind = .Return
	node_reserve_inputs(f, node, 2)
	set_node_input(f, node, prev_control, 0)
	set_node_input(f, node, expr, 1)
	return node
}

create_proj_node :: proc(f: ^Function, i: int, input: ^Node) -> ^Node {
	node := create_node(f)
	node.kind = .Proj
	node.vint = i64(i)
	node_reserve_inputs(f, node, 1)
	set_node_input(f, node, input, 0)

	return node
}

create_const_int_node :: proc(f: ^Function, v: i64) -> ^Node {
	node := create_node(f)
	node.kind = .Const
	node.type.kind = .I64
	node.vint = v
	node_reserve_inputs(f, node, 1)
	set_node_input(f, node, f.start, 0)
	return node
}

create_bin_op_node :: proc(f: ^Function, op: Node_Kind, lhs, rhs: ^Node) -> ^Node {
	node := create_node(f)
	node.kind = op
	node_reserve_inputs(f, node, 2)
	set_node_input(f, node, lhs, 0)
	set_node_input(f, node, rhs, 1)

	peephole(f, node)
	return node 
}

create_node :: proc(f: ^Function) -> ^Node {
	context.allocator = vmem.arena_allocator(&f.node_arena)
	if f.node_free_list == nil {
		node := new(Node)
		return node
	}

	node := &f.node_free_list.node
	f.node_free_list = f.node_free_list.next

	mem.zero_item(node)

	return node
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


set_node_input :: proc(f: ^Function, user, input: ^Node, slot: u16) {
	assert(slot < user.inputcap) // will give us runtime error
	user.inputs[slot] = input
	user.inputlen = max(user.inputlen, slot+1)
	if input != nil do add_node_user(f, user, input, slot)
}

add_node_input :: proc(f: ^Function, user, input: ^Node) -> (slot: u16) {
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

	input.users[slot] = Node_User{
		ptr = transmute(uintptr)user,
		slot = slot,
	}

	input.userlen += 1
}

