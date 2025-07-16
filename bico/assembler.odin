package bico32

Reg_Kind :: enum u8 {
	Zero,
	RA,
	GP,
	SP,
	FP,
	A0,
	A1,
	A2,
	A3,
	A4,
	A5,
	A6,
	A7,
	S0, 
	S1, 
	S2, 
	S3, 
	S4, 
	S5,
	S6,
	S7,
	S8, 
	S9, 
	S10, 
	S11,
	T0,
	T1,
	T2,
	T3,
	T4,
	T5,
	T6,
	T7,
}

Instruction_Kind :: enum u8 {
	Reg,
	Imm,
	Jump,
	JumpL,
}

Bi_Op_Code :: enum u8 {
	add,
	sub,
	mul,
	div,
	rem,
	or,
	xor,
	and,

}

Instruction_Bi_Op :: bit_field u32 {
	kind: 		Instruction_Kind|7,
	opcode:		Bi_Op_Code|5,
	dst: 		Reg_Kind|5,
	a:			Reg_Kind|5,
	b:			Reg_Kind|5,
}

Jump_Op_Code :: enum u8 {
	jeq,
	jneq,
	jltu,
	jlt,
	jgeu,
	jge,
}

Jump_Op :: bit_field u32 {
	kind: 		Instruction_Kind|7,
	opcode:		Jump_Op_Code|3,
	a:			Reg_Kind|5,
	b:			Reg_Kind|5,
	imm:	   	u16|12
}


Token_Kind :: enum {
	Mnemonic,
	Register,
	Comma,
	NewLine
	Label,
	Number,
	RBracket,
	LBracket,
}

Token :: struct {
	kind: Token_Kind,
	start, end: u32
}

Assembler :: struct {
	text: []u8
	tokens: [dynamic]Token
	curr, prev: int,
}

append_token

assemble :: proc(a: ^Assembler, code: [dynamic]u32) {
	for a.curr < len(a.text) {
		a.prev = a.curr
		ch := a.text[a.curr]
		case ' ':
		case ','
		case '\n'
	}
}