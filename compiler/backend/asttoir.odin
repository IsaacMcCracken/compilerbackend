package backend

import "../frontend"
import "core:fmt"


to_ir_fn_decl :: proc(f: ^Function, fn: ^frontend.Fn_Decl) {
	f.start = create_start_node(f)
	f.stop = create_stop_node(f)
	fn_scope := create_scope_node(f, f.start)
	f.scope = fn_scope
	// add projections for parameters
	for param, i in fn.params {
		create_fn_arg_node(f, param.name, i)
	}
	// graph body
	to_ir_body(f, fn_scope, f.start, &fn.body)
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
				cond := to_ir_expression(f, scope_node,  kind.cond)
				if_node, true_node, false_node := create_if_node(f, prev_control, cond)
				true_scope := create_scope_node(f, true_node, scope_node)
				to_ir_body(f, true_scope, true_node, &kind.body)
				prev_control = false_node

				region := create_region_node(f, true_node, false_node)

				if stmt_index + 1 < len(block.stmts) {
					else_stmt, else_ok := block.stmts[stmt_index + 1].(^frontend.Else_Stmt)
					if else_ok {
						false_scope := create_scope_node(f, false_node, scope_node)
						to_ir_body(f, false_scope, false_node, &else_stmt.body)
						
						
						continue
					} 
				} 

				true_scope_map := transmute(^Node_Scope)true_scope.vptr
				for name, slot in true_scope_map.symbols {
					tnode := true_scope.inputs[slot]
					fnode := scope_lookup_symbol(f, scope_node, name) 
					if  fnode != nil {
						create_phi(f, name, scope_node, region, tnode, fnode)
					}
				}


			case ^frontend.Else_Stmt:
				continue


		}	

		if prev_control.kind == .Proj && prev_control.inputs[0].kind == .If {

		}
	}	
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