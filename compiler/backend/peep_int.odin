package backend


@private node_position :: proc(n: ^Node) -> u8 {
	#partial switch n.kind {
		case .Const: return 1
		case .Add: return 2
		case: return 4
	}
}

int_peep :: proc(g: ^Function, n: ^Node) {
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