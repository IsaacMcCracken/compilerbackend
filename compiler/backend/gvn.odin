package backend

import "base:runtime"
import "core:slice"
import "core:hash"
import "core:fmt"

Node_Map_Cell :: struct {
	node: ^Node,
	next: ^Node_Map_Cell
}

Node_Map :: struct {
	cells: [^]^Node_Map_Cell,
	len, cap: int,
	allocator: runtime.Allocator
}



node_equal_proc ::  proc "contextless" (a, b: ^Node) -> bool {
	if a.inputlen != b.inputlen do return false
	return a.kind == b.kind && a.vint == b.vint && runtime.memory_compare(a.inputs, b.inputs, int(a.inputlen)) == 0
}

node_hasher_proc ::  proc "contextless" (data: rawptr, seed: uintptr = 0) -> uintptr {
	node := transmute(^Node)data
	input_bytes := slice.to_bytes(node.inputs[:node.inputlen])
	input_hash := hash.djb2(input_bytes)
	return ((uintptr(node.kind)<<31) | uintptr(input_hash) ) + uintptr(node.vint)
}

node_map_lookup :: proc(f: ^Function, n: ^Node) -> (node: ^Node, ok: bool) {
	hash := int(node_hasher_proc(n))
	index := hash % f.nmap.cap
	cell := f.nmap.cells[index]
	
	for cell != nil {
		if node_equal_proc(n, cell.node) do return cell.node, true
		cell = cell.next
	}

	return nil, false
}

node_map_insert :: proc(f: ^Function, n: ^Node) {
	context.allocator = f.nmap.allocator
	hash := int(node_hasher_proc(n))
	index := hash % f.nmap.cap
	pcell := &f.nmap.cells[index]
	
	for pcell^ != nil {
		// all ready inside map
		if node_equal_proc(n, pcell^.node) do return 
		pcell = &pcell^.next
	}

	err: runtime.Allocator_Error
	pcell^, err = new(Node_Map_Cell)
	pcell^.node = n
}

make_node_map :: proc(log2_capacity: int, allocator := context.allocator, loc:=#caller_location) -> (Node_Map, runtime.Allocator_Error) {
	context.allocator = allocator
	cells, err := make([^]^Node_Map_Cell, log2_capacity)
	return Node_Map{
		cells = cells,
		cap = log2_capacity,
		allocator = allocator
	}, err
}
