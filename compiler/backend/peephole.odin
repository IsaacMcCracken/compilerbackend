package backend


peephole :: proc(g: ^Function, n: ^Node) {
	#partial switch n.kind {
		case .Equals, .Less_Than, .Less_Than_Equal, .Greater_Than, .Greater_Than_Equal:
			bool_peep(g, n)
		case .Add, .Sub, .Mul, .Div:
			int_peep(g, n)
	}
}

bool_peep :: proc(g: ^Function, n: ^Node) {
	lhs, rhs := n.inputs[0], n.inputs[1]

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
}