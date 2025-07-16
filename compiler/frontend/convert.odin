package frontend

import "../../format"
import "core:strconv"

Converter :: struct { 
	using p: format.Parser

}

Decl_Flags :: bit_set[Decl_Flag; u32]
Decl_Flag :: enum u32 {
	Fn,
	Ret,
}


convert_tree_to_ast :: proc(c: ^Converter) -> []Any_Decl {
	count := format.count(c.root.children)
	iter := format.iterator_head(c.root.children)
	decls := make([]Any_Decl, count)
	i := 0
	for decl in format.iterate_next(&iter) {
		fn, fok := convert_fn(c, decl)
		if fok {
			decls[i] = fn
			i += 1
		}  
	}

	return decls
}

convert_field_list :: proc(c: ^Converter, list: format.List) -> []Field {
	iter := format.iterator_head(list)
	count := format.count(list)
	fields := make([]Field, count)
	i := 0
	for field in format.iterate_next(&iter) {
		name := format.get_name(c, field)
		if !format.is_singleton(&field.tags) {
			//error
			panic("fringeg")
		}

		// convert_type
		type_name := format.get_name(c, field.tags.head)
		if type_name != "T" {
			panic("FUCK")
		}

		fields[i] = Field{
			name = name
			// todo type
		}

		i += 1
	}



	return fields
}

convert_var_decl :: proc(c: ^Converter, n: ^format.Node) -> (var: ^Var_Decl, ok: bool) {
	iter := format.iterator_head(n.tags)
	// assume this syntax @var(@int x) = (69)
	for tag in format.iterate_next(&iter) {
		name := format.get_name(c, tag)
		if name == "var" {
			var = new(Var_Decl)
			// var.name = format.get_name(c, n)
			assert(format.is_singleton(&tag.children))
			var.name = format.get_name(c, tag.children.head)
			var.init = convert_expression(c, n.children.tail)
			return var, true
		}
	}


	return
}

convert_fn :: proc(c: ^Converter, n: ^format.Node) -> (fn: ^Fn_Decl, ok: bool) {
	iter := format.iterator_head(n.tags)

	for tag in format.iterate_next(&iter) {
		name := format.get_name(c, tag)


		switch name {
		case "fn":
			ok = true
			if fn == nil do fn = new(Fn_Decl)
			fn.params = convert_field_list(c, tag.children)
		case "ret":
			ok = true
			if fn == nil do fn = new(Fn_Decl)
			// TODO type system
			// fn.ret_type = ---
		}
	}

	if ok {
		fn.name = format.get_name(c, n)
		fn.body = convert_block(c, n.children)
	}



	return
}

convert_if_statement :: proc(c: ^Converter, n: ^format.Node) -> (stmt: ^If_Stmt, ok: bool) {
	expr: Any_Expr

	iter := format.iterator_head(n.tags)
	for tag in format.iterate_next(&iter) {
		tag_name := format.get_name(c, tag)
		if tag_name == "cond" && format.is_singleton(&tag.children) {
			ok = true
			expr = convert_expression(c, tag.children.head)
		}
	}

	if ok {
		stmt = new(If_Stmt)
		stmt.cond = expr
		stmt.body = convert_block(c, n.children)
	}

	return 
}

convert_expression :: proc(c: ^Converter, n: ^format.Node) -> Any_Expr {

	name := format.get_name(c, n)
	child_count := format.count(n.children)
	
	op: Binary_Op
	switch name {
		case "+": op = .Add
		case "-": op = .Sub
		case "*": op = .Mul
		case "/": op = .Div
		case "==": op = .Equals
		case "<": op = .Less_Than
		case "<=": op = .Less_Than_Equal
		case ">": op = .Greater_Than
		case ">=": op = .Greater_Than_Equal
	}

	if op != .Invalid {
		assert(child_count == 2)
		operator := new(Binary_Expr)
		operator.op = op
		operator.lhs = convert_expression(c, n.children.head)
		operator.rhs = convert_expression(c, n.children.tail)
		return operator
	}
	

	if child_count == 0 {
		integer, iok := strconv.parse_int(name)
		if iok {
			obj := new(Number_Obj)
			obj^ = i64(integer)
			return obj
		} 

		float, fok := strconv.parse_f64(name)
		if fok {
			obj := new(Number_Obj)
			obj^ = float
			return obj
		}

		obj := new(Named_Obj)
		obj.name = name 

		return obj
	}

	// function call like thing or array indexing

	return nil
}

convert_block :: proc(c: ^Converter, list: format.List) -> (block: Block) {
	count := format.count(list)
	block.stmts = make([]Any_Stmt, count)

	iter := format.iterator_head(list)
	i := 0
	for stmt in format.iterate_next(&iter) {
		stmt_name := format.get_name(c, stmt)
		switch stmt_name {
			case "return":
				ret := new(Return_Stmt)

				ret.expr = convert_expression(c, stmt.children.head)
				block.stmts[i] = ret
			case "if":
				_if, iok := convert_if_statement(c, stmt)
				if iok {
					block.stmts[i] = _if
				}
			case "else":
				_else := new(Else_Stmt)
				_else.body = convert_block(c, stmt.children)
				block.stmts[i] = _else
			case "=":
				var, vok := convert_var_decl(c, stmt)
				if vok {
					block.stmts[i] = var
				} else {
					update := new(Update_Stmt)
					update.name = format.get_name(c, stmt.children.head)
					update.expr = convert_expression(c, stmt.children.tail)
					block.stmts[i] = update
				}
			case:

		}
		i += 1
	}

	return block
} 