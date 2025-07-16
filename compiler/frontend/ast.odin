package frontend


Numeric_Type :: bit_field u8 {
	size: u8 | 4,
	is_float: bool | 1,
	signed: bool | 1,
}



Fn_Type :: struct {
	params: []Field
}

Fn_Decl :: struct {
	name: string,
	using type: Fn_Type,
	body: Block,
	// ret_type -> assume integer for now
}



Var_Decl :: struct {
	name: string,
	type: Type, 
	init: Any_Expr,
}

Field :: struct {
	name: string,
	type: Type,
}

Named_Obj :: struct {
	name: string
}

Number_Obj :: union #no_nil {
	f64,
	i64
}

Binary_Op :: enum {
	Invalid,
	Add,
	Sub,
	Mul,
	Div,
	Equals,
	Less_Than,
	Less_Than_Equal,
	Greater_Than,
	Greater_Than_Equal,
}

Binary_Expr :: struct {
	lhs, rhs: Any_Expr,
	op: Binary_Op
}

If_Stmt :: struct {
	cond: Any_Expr,
	body: Block,
}

Else_Stmt :: struct {
	body: Block
}

Update_Stmt :: struct {
	//fix
	name: string,
	expr: Any_Expr,
}

Return_Stmt :: struct {
	expr: Any_Expr
}

Block :: struct {
	stmts: []Any_Stmt
}

Any_Expr :: union #shared_nil {
	^Named_Obj,
	^Number_Obj,
	^Binary_Expr,
}

Any_Stmt :: union #shared_nil {
	^Var_Decl,
	^Update_Stmt,
	^Return_Stmt,
	^If_Stmt,
	^Else_Stmt,

}

Any_Decl :: union #shared_nil {
	^Var_Decl,
	^Fn_Decl,
}

Type :: union #shared_nil {
	^Numeric_Type
}