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
	prev_control := prev_control
	for stmt, stmt_index in block.stmts {
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
				if_node.kind = .If
				if_node.type = Node_Type{kind = .Control}
				cond := to_ir_expression(f, scope_node,  kind.cond)
				node_reserve_inputs(f, if_node, 2)
				node_reserve_users(f, if_node, 2)
				set_node_input(f, if_node, prev_control, 0)
				set_node_input(f, if_node, cond, 1)
				true_case := create_proj_node(f, 0, if_node)
				true_scope := create_scope_node(f, true_case, scope_node)
				to_ir_body(f, true_scope, if_node, &kind.body)
				if f.first == nil do f.first = if_node
				prev_control = if_node
			case ^frontend.Else_Stmt:
				assert(prev_control.kind == .If)
				false_case := create_proj_node(f, 1, prev_control)
				false_scope := create_scope_node(f, false_case, scope_node)
				to_ir_body(f, false_scope, prev_control, &kind.body)

				// merge control

				region := create_node(f)
				region.kind = .Region

				inner_scopes := [2]^Node{}
				cases := get_node_users(prev_control)
				assert(len(cases) == 2)

				for some_case, i in cases {
					real_case, _ := unwrap_user(some_case)
					scope, ok := get_scope_from_node(real_case)
					assert(ok)
					inner_scopes[i] = scope
				}

				outer_symbol_table := transmute(^Node_Scope)scope_node.vptr
				for sym_name, sym_slot in outer_symbol_table.symbols {
					phi_inputs := [2]^Node{}
					phi_count := 0

					for inner in inner_scopes {
						inner_symbol_table := transmute(^Node_Scope)inner.vptr

						slot, ok := inner_symbol_table.symbols[sym_name]


						if ok {

							phi_inputs[phi_count] = inner.inputs[slot] 
							phi_count += 1
						}
					}

					if phi_count == 1 do phi_inputs[1] = scope_node.inputs[sym_slot]

					if phi_count > 0 {
						_ = create_phi_2(f, sym_name, scope_node, region, phi_inputs)
					}
				}


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