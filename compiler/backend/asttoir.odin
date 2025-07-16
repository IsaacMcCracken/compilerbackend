package backend

import "../frontend"



to_ir_fn_decl :: proc(f: ^Function, fn: ^frontend.Fn_Decl) {
	start := create_node(f)
	start.kind = .Start

	f.start = start
	fn_scope := create_scope_node(f, start)
	f.scope = fn_scope
	// add projections for parameters
	for param, i in fn.params {
		create_fn_arg_node(f, param.name, i)
	}
	// graph body
	to_ir_body(f, fn_scope, start, &fn.body)
	// add
}

to_ir_body :: proc(f: ^Function, scope_node, prev_control: ^Node, block: ^frontend.Block) {
	for stmt in block.stmts {
		switch kind in stmt {
			case ^frontend.Var_Decl:
				node := to_ir_expression(f, scope_node,  kind.init)
				scope_update_symbol(f, scope_node, kind.name, node)
			case ^frontend.Update_Stmt:
				node := to_ir_expression(f, scope_node,  kind.expr)
				scope_update_symbol(f, scope_node, kind.name, node)
			case ^frontend.Return_Stmt:
				expr := to_ir_expression(f, scope_node,  kind.expr)
				ret := create_return_node(f, prev_control, expr)
			case ^frontend.If_Stmt:
				if_node := create_node(f)
				cond := to_ir_expression(f, scope_node,  kind.cond)
				node_reserve_inputs(f, if_node, 2)
				set_node_input(f, if_node, prev_control, 0)
				set_node_input(f, if_node, cond, 1)
				scope := create_scope_node(f, if_node, scope_node)
				
				if cond.kind == .Const && cond.vb32 == true {
					to_ir_body(f, scope_node, prev_control, &kind.body)
				} else {
					to_ir_body(f, scope, if_node, &kind.body)
				}			
			case ^frontend.Else_Stmt:
	}	}
}



to_ir_expression :: proc(f: ^Function, scope_node: ^Node, expr: frontend.Any_Expr) -> (node: ^Node) {
	@static op_map := #partial [frontend.Binary_Op]Node_Kind {
		.Invalid = .Invalid,
		.Add = .Add,
		.Sub = .Sub,
		.Mul = .Mul,
		.Div = .Div,
		.Equals = .Equals,
		.Less_Than = .Less_Than,
		.Less_Than_Equal = .Less_Than_Equal,
		.Greater_Than = .Greater_Than,
		.Greater_Than_Equal = .Greater_Than_Equal,
	}

	#partial switch kind in expr {
		case ^frontend.Named_Obj:
			node = scope_lookup_symbol(f, scope_node, kind.name)
			assert(node != nil)
		case ^frontend.Number_Obj:
			switch num_kind in kind {
				case i64:
					return create_const_int_node(f, num_kind)
				case f64: panic("no f64 rn")
			}
		case ^frontend.Binary_Expr:
			lhs := to_ir_expression(f, scope_node, kind.lhs)
			rhs := to_ir_expression(f, scope_node, kind.rhs)
			return create_bin_op_node(f, op_map[kind.op], lhs, rhs)

	}

	return
}