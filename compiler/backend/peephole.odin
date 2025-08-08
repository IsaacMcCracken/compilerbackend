package backend

import "core:fmt"

peephole :: proc(f: ^Function, n: ^Node) -> (out: ^Node) {
	node, ok := node_map_lookup(f, n)
	if ok {
		// kill n
		out = node
	} else {
		node_map_insert(f, n)
		out = n
	}

	#partial switch n.kind {
		case .Equals, .Less_Than, .Less_Than_Equal, .Greater_Than, .Greater_Than_Equal:
			out = bool_peep(f, n)
		case .Add, .Sub, .Mul, .Div:
			out = int_peep(f, n)
	}

	if n.userlen == 0 {
		// kill n
	}


	return out
}

@private node_position :: proc(n: ^Node) -> u8 {
	#partial switch n.kind {
		case .Const: return 1
		case .Add: return 2
		case: return 4
	}
}

int_peep :: proc(f: ^Function, n: ^Node) -> (out: ^Node) {
	// binary operation peepholes
	#partial switch n.kind {
	case .Add, .Sub, .Mul, .Div:
		lhs := n.inputs[0]
		rhs := n.inputs[1]
		// communitive peeholes
		if n.kind == .Add || n.kind == .Mul {
			// 5 + x = x + 5 --- C + (x + K) = (x + K) + C
			if lhs.kind == .Const && rhs.kind != .Const {
				return create_bin_op_node(f, n.kind, rhs, lhs)
			}
			
			// (x + K) + C = x + (K + C)
			if lhs.kind == n.kind && lhs.inputs[1].kind == .Const && rhs.kind == .Const {
				constfold := create_bin_op_node(f, n.kind, lhs.inputs[0], rhs)
				return create_bin_op_node(f, n.kind, lhs, constfold)
			}

			// ((x + C) + y) = ((x + y) + C)
			if lhs.kind == n.kind && lhs.inputs[1].kind == .Const && rhs.kind != .Const {
				inner := create_bin_op_node(f, n.kind, lhs.inputs[0], rhs)
				return create_bin_op_node(f, n.kind, inner, lhs.inputs[1])
			}



	
		}

		// addition peepholes 
		if n.kind == .Add {
			// x + 0 = x
			if rhs.kind == .Const && rhs.vint == 0 do return lhs
			// x + x = 2 * x
			if lhs == rhs do return create_bin_op_node(f, .Mul, lhs, create_const_int_node(f, 2))
		}
		// subtraction peepholes 
		if n.kind == .Sub  {
			// x - x = 0
			if lhs == rhs do return create_const_int_node(f, 0)
			// x - 0 = x
			if rhs.kind == .Const && rhs.vint == 0 do return lhs
		}

		// multiplication peepholes
		if n.kind == .Mul && rhs.kind == .Const {
			// x * 0 = 0
			if rhs.vint == 0 do return rhs
			// x * 1 = x
			if rhs.vint == 1 do return lhs
		}
		// division peepholes 
		// x / 1 = x
		if n.kind == .Div && rhs.kind == .Const && rhs.vint == 1 {
			return lhs
		}

		// constant folding peephole
		if lhs.kind == .Const && rhs.kind == .Const {
			
			result: i64
			#partial switch n.kind {
				case .Add: result = lhs.vint + rhs.vint
				case .Sub: result = lhs.vint - rhs.vint
				case .Mul: result = lhs.vint * rhs.vint
				case .Div: result = lhs.vint / rhs.vint
				case: unreachable()
			}

			return create_const_int_node(f, result)

		}
	}

	return n
}

bool_peep :: proc(f: ^Function, n: ^Node) -> (out: ^Node) {
	lhs, rhs := n.inputs[0], n.inputs[1]

	// if lhs == rhs {
	// 	#partial switch n.kind {
	// 		case .Equals: return 
	// 	}
	// }


	// use identity to swap so that constants are on the right hand side
	if lhs.kind == .Const && rhs.kind != .Const {


		@static swap_map := #partial [Node_Kind]Node_Kind {
			.Equals = .Equals,
			.Less_Than = .Greater_Than_Equal,
			.Less_Than_Equal = .Greater_Than,
			.Greater_Than = .Less_Than_Equal,
			.Greater_Than_Equal = .Less_Than,
		}

		kind := swap_map[n.kind]

		return create_bin_op_node(f, kind, rhs, lhs)
	}

	if lhs.kind == .Const && rhs.kind == .Const {
		// assert(lhs.type.kind == rhs.type.kind && lhs.type.kind == .Int)
		a, b := lhs.vint, rhs.vint
		result: b32 
		#partial switch n.kind {
			case .Equals: 				result = a == b
			case .Less_Than:			result = a < b
			case .Less_Than_Equal:		result = a <= b
			case .Greater_Than:			result = a > b
			case .Greater_Than_Equal:	result = a >= b	
			case: unreachable()
		}


		return create_const_int_node(f, i64(result))
	}

	return n
}

