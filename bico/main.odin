package bico32

import "core:fmt"

main :: proc() {
	vm := new(Bico32_VM)
	vm.r[5].s = 60
	vm.r[6].s = 9
	addop := transmute(u32)Instruction_Bi_Op {
		kind = 	.Reg,
		opcode = .add,
		dst = 	.A0,
		a = 	.A0, 
		b = 	.A1,
	}
	execute_single_instruction(vm, addop)
	fmt.println(vm.r[5].s)
}