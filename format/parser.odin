package format

import "core:fmt"



Parser :: struct {
	tokens: []Token,
	src: []byte,
	curr: int,
	root: ^Node
}

error :: proc(p: ^Parser, idx: u32, msg: string, args: ..any) {
	fmt.eprint("Error: ")
	fmt.eprintfln(msg, ..args)
}


// This data structure is two-pointers in size:
// 	8 bytes on 32-bit platforms and 16 bytes on 64-bit platforms
List :: struct {
	head: ^Node,
	tail: ^Node,
}

Node_Flags :: bit_set[Node_Flag; u32]
Node_Flag :: enum u32 {
	Is_Tag,
}

// The list link you must include in your own structure.
Node :: struct {
	prev, next: ^Node,
	children, tags: List,
	tok_idx: u32,
	flags: Node_Flags
}



get_name :: proc(p: ^Parser, n: ^Node) -> string {
	tok := p.tokens[n.tok_idx]
	start := tok.start
	if .Is_Tag in n.flags do start += 1
	end := tok.end
	return string(p.src[start:end])
}

/*
Inserts a new element at the front of the list with O(1) time complexity.

**Inputs**
- list: The container list
- node: The node member of the user-defined element structure
*/
push_front :: proc "contextless" (list: ^List, node: ^Node) {
	if list.head != nil {
		list.head.prev = node
		node.prev, node.next = nil, list.head
		list.head = node
	} else {
		list.head, list.tail = node, node
		node.prev, node.next = nil, nil
	}
}
/*
Inserts a new element at the back of the list with O(1) time complexity.

**Inputs**
- list: The container list
- node: The node member of the user-defined element structure
*/
push_back :: proc "contextless" (list: ^List, node: ^Node) {
	if list.tail != nil {
		list.tail.next = node
		node.prev, node.next = list.tail, nil
		list.tail = node
	} else {
		list.head, list.tail = node, node
		node.prev, node.next = nil, nil
	}
}


count :: proc(list: List) -> int {
	n := 0
	iter := iterator_head(list)
	for node in iterate_next(&iter) do n += 1
	return n
}
/*
Removes an element from a list with O(1) time complexity.

**Inputs**
- list: The container list
- node: The node member of the user-defined element structure to be removed
*/
remove :: proc "contextless" (list: ^List, node: ^Node) {
	if node != nil {
		if node.next != nil {
			node.next.prev = node.prev
		}
		if node.prev != nil {
			node.prev.next = node.next
		}
		if list.head == node {
			list.head = node.next
		}
		if list.tail == node {
			list.tail = node.prev
		}
	}
}
/*
Removes from the given list all elements that satisfy a condition with O(N) time complexity.

**Inputs**
- list: The container list
- to_erase: The condition procedure. It should return `true` if a node should be removed, `false` otherwise
*/
remove_by_proc :: proc(list: ^List, to_erase: proc(^Node) -> bool) {
	for node := list.head; node != nil; {
		next := node.next
		if to_erase(node) {
			if node.next != nil {
				node.next.prev = node.prev
			}
			if node.prev != nil {
				node.prev.next = node.next
			}
			if list.head == node {
				list.head = node.next
			}
			if list.tail == node {
				list.tail = node.prev
			}
		}
		node = next
	}
}
/*
Removes from the given list all elements that satisfy a condition with O(N) time complexity.

**Inputs**
- list: The container list
- to_erase: The _contextless_ condition procedure. It should return `true` if a node should be removed, `false` otherwise
*/
remove_by_proc_contextless :: proc(list: ^List, to_erase: proc "contextless" (^Node) -> bool) {
	for node := list.head; node != nil; {
		next := node.next
		if to_erase(node) {
			if node.next != nil {
				node.next.prev = node.prev
			}
			if node.prev != nil {
				node.prev.next = node.next
			}
			if list.head == node {
				list.head = node.next
			}
			if list.tail == node {
				list.tail = node.prev
			}
		}
		node = next
	}
}

/*
Checks whether the given list does not contain any element.

**Inputs**
- list: The container list

**Returns** `true` if `list` is empty, `false` otherwise
*/
is_empty :: proc "contextless" (list: ^List) -> bool {
	return list.head == nil
}


is_singleton :: proc "contextless" (list: ^List) -> bool {
	return list.head == list.tail
}



/*
Removes and returns the element at the front of the list with O(1) time complexity.

**Inputs**
- list: The container list

**Returns** The node member of the user-defined element structure, or `nil` if the list is empty
*/
pop_front :: proc "contextless" (list: ^List) -> ^Node {
	link := list.head
	if link == nil {
		return nil
	}
	if link.next != nil {
		link.next.prev = link.prev
	}
	if link.prev != nil {
		link.prev.next = link.next
	}
	if link == list.head {
		list.head = link.next
	}
	if link == list.tail {
		list.tail = link.prev
	}
	return link

}
/*
Removes and returns the element at the back of the list with O(1) time complexity.

**Inputs**
- list: The container list

**Returns** The node member of the user-defined element structure, or `nil` if the list is empty
*/
pop_back :: proc "contextless" (list: ^List) -> ^Node {
	link := list.tail
	if link == nil {
		return nil
	}
	if link.next != nil {
		link.next.prev = link.prev
	}
	if link.prev != nil {
		link.prev.next = link.next
	}
	if link == list.head {
		list.head = link.next
	}
	if link == list.tail {
		list.tail = link.prev
	}
	return link
}



Iterator :: struct {
	curr:   ^Node,
}


iterator_head :: proc "contextless" (list: List) -> Iterator {
	return {list.head}
}

iterator_from_node :: proc "contextless" (node: ^Node) -> Iterator {
	return {node}
}


iterate_next :: proc "contextless" (it: ^Iterator) -> (n: ^Node, ok: bool) {
	node := it.curr
	if node == nil {
		return nil, false
	}
	it.curr = node.next

	return node, true
}

iterate_prev :: proc "contextless" (it: ^Iterator) -> (n: ^Node, ok: bool) {
	node := it.curr
	if node == nil {
		return nil, false
	}
	it.curr = node.prev

	return node, true
}

parser_current_token :: proc(p: ^Parser) -> (tok: Token, index: u32) {
	return p.tokens[p.curr], u32(p.curr)
}

parser_advance_token :: proc(p: ^Parser) -> (tok: Token, index: u32) {
	p.curr += 1
	return p.tokens[p.curr], u32(p.curr)
}

parse :: proc(p: ^Parser, allocator:=context.allocator) {
	parse_tags :: proc(p: ^Parser) -> (list: List) {
		tok, idx := parser_current_token(p)

		for tok.kind == .Tag {
			tag := new(Node)
			tag.tok_idx = idx
			tag.flags = {.Is_Tag}


			tok, idx = parser_advance_token(p)

			if tok.kind == .Open {
				tag.children = parse_children(p)
				tok, idx = parser_advance_token(p)
			}

			push_back(&list, tag)
		}
		return
	}



	parse_children :: proc(p: ^Parser) -> (list: List) {
		// enter on open
		tok, idx := parser_advance_token(p)
		for tok.kind != .Close {
			tags := parse_tags(p)

			tok, idx = parser_current_token(p)
			if tok.kind != .Identifier {
				error(p, idx, "what")
				assert(false)
			}
			child := new(Node)
			child.tok_idx = idx 
			child.tags = tags

			tok, idx = parser_advance_token(p)

			if tok.kind == .Open {
				child.children = parse_children(p)
				tok, idx = parser_advance_token(p)
			}

			push_back(&list, child)

		}

		return
	}


	context.allocator = allocator
	tags := parse_tags(p)
	children: List
	tok, idx := parser_current_token(p)
	if tok.kind != .Identifier {
		error(p, idx, "Expected package name here")
		return
	}

	p.root = new(Node)
	p.root.tok_idx = idx // idx == 1


	tok, idx = parser_advance_token(p)
	if tok.kind == .Open {
		children = parse_children(p)
	}

	p.root.tags = tags
	p.root.children = children
}