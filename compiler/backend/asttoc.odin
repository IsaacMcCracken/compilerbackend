package backend

import "../frontend"
import "core:strings"
import "core:fmt"



to_c_fn_decl :: proc(fn: ^frontend.Fn_Decl, b: ^strings.Builder) {
	fmt.sbprintf(b, "int %s(", fn.name)

	for field, i in fn.params {

		fmt.sbprintf(b, "int %s", field.name)

		if i != len(fn.params) - 1 {
			strings.write_string(b, ", ")
		}
	}

	fmt.sbprint(b, ")\n")


	to_c_block(fn.body, b)
}

to_c_block :: proc(block: frontend.Block, b: ^strings.Builder, indent := 0) {
 	for _ in 0..<indent do strings.write_string(b, "  ")
 	strings.write_string(b, "{\n")

 	for stmt in block.stmts {
 		to_c_statement(stmt, b, indent + 1)
 	}

 	for _ in 0..<indent do strings.write_string(b, "  ")
 	strings.write_string(b, "}\n")
}

to_c_statement :: proc(stmt: frontend.Any_Stmt, b: ^strings.Builder, indent: int) {
	for _ in 0..<indent do strings.write_string(b, "  ")

	switch kind in stmt {
	case ^frontend.Var_Decl:
		fmt.sbprintf(b, "int %s = ", kind.name)
		to_c_expression(kind.init, b)
		strings.write_string(b, ";\n")
	case ^frontend.Update_Stmt:
		fmt.sbprintf(b, "%s = ", kind.name)
		to_c_expression(kind.expr, b)
		strings.write_string(b, ";\n")
	case ^frontend.Return_Stmt:
		strings.write_string(b, "return ")
		to_c_expression(kind.expr, b)
		strings.write_string(b, ";\n")
	case ^frontend.If_Stmt:
		strings.write_string(b, "if (")
		to_c_expression(kind.cond, b)
		strings.write_string(b, ")\n")
		to_c_block(kind.body, b)
	case ^frontend.Else_Stmt: 
		strings.write_string(b, "else\n")
		to_c_block(kind.body, b)
	}
}


to_c_expression :: proc(expr: frontend.Any_Expr, b: ^strings.Builder) {
	@static op_map := #partial [frontend.Binary_Op]string {
		.Add = "+",
		.Sub = "-",
		.Mul = "*",
		.Div = "/",
		.Less_Than = "<",
		.Less_Than_Equal = "<=",
		.Greater_Than = ">",
		.Greater_Than_Equal = ">=",
	}
	switch kind in expr {
		case ^frontend.Binary_Expr:
			to_c_expression(kind.lhs, b)
			fmt.sbprintf(b, " %s ", op_map[kind.op])
			to_c_expression(kind.rhs, b)
		case ^frontend.Number_Obj:
			switch num_kind in kind {
				case f64:
					fmt.sbprint(b, num_kind)
				case i64:
					fmt.sbprint(b, num_kind)
			}
		case ^frontend.Named_Obj:
			strings.write_string(b, kind.name)
	}
}

