package backend


peephole :: proc(f: ^Function, n: ^Node) -> (node: ^Node) {
	#partial switch n.kind {
		case .Equals, .Less_Than, .Less_Than_Equal, .Greater_Than, .Greater_Than_Equal:
			return bool_peep(g, n)
		case .Add, .Sub, .Mul, .Div:
			return int_peep(g, n)
	}

	return n
}

@private node_position :: proc(n: ^Node) -> u8 {
	#partial switch n.kind {
		case .Const: return 1
		case .Add: return 2
		case: return 4
	}
}

int_peep :: proc(g: ^Function, n: ^Node) -> (out: ^Node) {
	#partial switch n.kind {
	case .Add, .Sub, .Mul, .Div:
		lhs := n.inputs[0]
		rhs := n.inputs[1]

		#partial switch n.kind {
			// switch constants and operators to the right hand side
			// (4 + (x + 3)) ===> ((x + 3) + 4)
			case .Add, .Mul:
			if lhs.kind == .Const && rhs.kind != .Const {
				n.inputs[0], n.inputs[1] = n.inputs[1], n.inputs[0] 
				lhs = n.inputs[0]
				rhs = n.inputs[1]			
			} 



			// if the right hand side is a comunitive 
			// operator we can rewrite the graph

			// example ((x + 3) + 4)
			// we can rewrite as (x + (3 + 4))
			// so that we can peephole to make
			// (x + 7)
			if lhs.kind == n.kind {
				n.inputs[0], n.inputs[1] = n.inputs[1], n.inputs[0] // operator is now on lhs
				rhs = n.inputs[1]	
				rhs.inputs[0], n.inputs[0] = n.inputs[0], rhs.inputs[0]
				lhs = n.inputs[0]
				rhs = n.inputs[1]	
				int_peep(g, rhs)
			}


			if rhs.kind == .Const && rhs.vint == 0 {
				n.kind = lhs.kind	
				n.vint = lhs.vint
			}
		}

		if lhs.kind == .Const && rhs.kind == .Const {
			result: i64
			#partial switch n.kind {
				case .Add: result = lhs.vint + rhs.vint
				case .Sub: result = lhs.vint - rhs.vint
				case .Mul: result = lhs.vint * rhs.vint
				case .Div: result = lhs.vint / rhs.vint
				case: unreachable()
			}

			// destroy_node(g, lhs)
			// destroy_node(g, rhs)

			n.kind = .Const
			n.vint = result
		}
	}
}

bool_peep :: proc(g: ^Function, n: ^Node) -> (out: ^Node) {
	lhs, rhs := n.inputs[0], n.inputs[1]

	if lhs.kind == .Const && rhs.kind != .Const {
		nlhs := n.inputs[1]
		nrhs := n.inputs[0]


		@static swap_map := #partial [Node_Kind]Node_Kind {
			.Equals = .Equals
			.Less_Than = .Greater_Than_Equal
			.Less_Than_Equal = .Greater_Than
			.Greater_Than = .Less_Than_Equal
			.Greater_Than_Equal = .Less_Than
		}

		kind := swap_map[n.kind]

		destroy_node(f, n)
		return create_bin_op_node(f, kind, nlhs, nrhs)
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
			// disconect inputs
		// inputs := get_node_inputs(n)
		// for input in inputs {
		// 	inputs_outputs := get_node_inputs(input)
		// 	for output, i in inputs_outputs {
		// 		if output == n {
		// 			node_remove_user(g, input, i)
		// 		}
		// 	}
		// }

		n.kind = .Const
		n.vb32 = result
	}

	return n
}