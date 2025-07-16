package bico32

import "core:simd"

Virtual_Register :: struct #raw_union {
	u: u32,
	s: i32,
}

Float_Register :: struct #raw_union {
	f: f32
}

Vector_Register :: struct #raw_union {
	f128: simd.f32x4,
	s128: simd.i32x4,
}

Bico32_VM :: struct {
	r: [32]Virtual_Register,
	f: [32]Float_Register,
	pc: u32,
	/* 
		First  Page of mem is os data
		Second Page of mem is page table
	*/
	mem: [4<<24]u8,
}

Page_Flags :: bit_set[Page_Flag; u8]
Page_Flag :: enum u8 {
	Execute,
	Read,
	Write,
}

Page_Table_Entry :: bit_field u8 {
	flags: Page_Flags | 3,
}
execute_single_instruction :: proc(vm: ^Bico32_VM, inst: u32) {
	kind := transmute(Instruction_Kind)u8(inst&((1<<6)-1))
	#partial switch kind {
		case .Reg: execute_reg_instruction(vm, transmute(Instruction_Bi_Op)inst)
	}
}

execute_reg_instruction :: proc(vm: ^Bico32_VM, op: Instruction_Bi_Op) {
	dst, a, b := u8(op.dst), u8(op.a), u8(op.b)
	switch op.opcode {
		case .add: vm.r[dst].s = vm.r[a].s + vm.r[b].s
		case .sub: vm.r[dst].s = vm.r[a].s - vm.r[b].s
		case .mul: vm.r[dst].s = vm.r[a].s * vm.r[b].s
		case .div: vm.r[dst].s = vm.r[a].s / vm.r[b].s
		case .rem: vm.r[dst].s = vm.r[a].s % vm.r[b].s
		case .or:  vm.r[dst].u = vm.r[a].u | vm.r[b].u
		case .and: vm.r[dst].u = vm.r[a].u & vm.r[b].u
		case .xor: vm.r[dst].u = vm.r[a].u ~ vm.r[b].u
	}
}

start_process :: proc(vm: ^Bico32_VM) {
	os_data: struct {
		page_ptr: &transmute(^u32)(&vm.mem[0])
		free_ptr: &transmute(^u32)(^vm.mem[4])
	}
}

execute_syscall_valloc :: proc(vm: ^Bico32_VM) {
	npages := vm.r[int(Reg_Kind.A0)].s
	os_data: struct {
		page_ptr: &transmute(^u32)(&vm.mem[0])
		free_ptr: &transmute(^u32)(^vm.mem[4])
	}

	if os_data.free_ptr > 0 {
		
	} else os.page_ptr if ^ >= 0xFFFFFF {
		vm.r[int(Reg_Kind.A1)].s = 0,
	} else {
		vm.r[int(Reg_Kind.A0)].s = dptr^
	}
}