package x86_64

Emitter :: struct {
	code: [dynamic]byte,
}

Register :: enum {
    RAX,  	// Accumulator
    RCX,  	// Counter
    RDX,  	// Data
    RBX,  	// Base
    RSP,  	// Stack Pointer
    RBP,  	// Base Pointer
    RSI,  	// Source Index
    RDI,  	// Destination Index
    R8,  	// Extended register 8
    R9,  	// Extended register 9
    R10, 	// Extended register 10
    R11, 	// Extended register 11
    R12, 	// Extended register 12
    R13, 	// Extended register 13
    R14, 	// Extended register 14
    R15, 	// Extended register 15
	XMM0,	// Vector register 0
    XMM1,	// Vector register 1
    XMM2,	// Vector register 2
    XMM3,	// Vector register 3
    XMM4,	// Vector register 4
    XMM5,	// Vector register 5
    XMM6,	// Vector register 6
    XMM7,	// Vector register 7
    XMM8,	// Vector register 8
    XMM9,	// Vector register 9
    XMM10,	// Vector register 10
    XMM11,	// Vector register 11
    XMM12,	// Vector register 12
    XMM13,	// Vector register 13
    XMM14,	// Vector register 14
    XMM15,	// Vector register 15
}



encode_reg_mov :: proc(e: ^Emitter, dst, src: Register) {
	rex_prefix(e, src, dst)
	append(&e.code, 0x89)
	reg_mod_rm_registers(e, src, dst)
}

encode_load_imm :: proc(e: ^Emitter, reg: Register, imm: i64) {
	abs_imm := abs(imm)
	if abs_imm <= i64(max(i32)) {
		rex_prefix(e, Register(0), reg, false)
		imm32 := i32le(imm)
		bytes := transmute([4]byte)imm32
		append(&e.code, 0xC7)
		reg_mod_rm_registers(e, Register(0), reg)
		for b in bytes do append(&e.code, b)
	} else {
		rex_prefix(e, Register(0), reg, false)
		imm64 := i64le(imm)
		bytes := transmute([8]byte)imm64
		append(&e.code, 0xB8 + (0x7 & u8(reg)))
		for b in bytes do append(&e.code, b)
	}
}

encode_mul_imm :: proc(e: ^Emitter, reg, rm: Register, imm: i64) {
	abs_imm := abs(imm)
	if abs_imm <= i64(max(i8)) {
		rex_prefix(e, reg, rm)
		append(&e.code, 0x6B)
		reg_mod_rm_registers(e, reg, rm)
		b := transmute(u8)i8(imm)
		append(&e.code, b)
	} else if abs_imm <= i64(max(i32)) {
		rex_prefix(e, reg, rm)
		append(&e.code, 0x69)
		reg_mod_rm_registers(e, reg, rm)
		imm32 := i32(imm)
		bytes := transmute([size_of(i32)]byte)imm32
		for b in bytes do append(&e.code, b)
	} else {
		panic("FUDGE")
	}
}

encode_vec_fsqrt :: proc(e: ^Emitter, dst, src: Register) {
	rex_prefix(e, dst, src, false)
	append(&e.code, 0x0F, 0x51)
	reg_mod_rm_registers(e, dst, src)
}



encode_vec_add_4xf32 :: proc(e: ^Emitter, a, b: Register) {
	rex_prefix(e, a, b, false)
	append(&e.code, 0x0F, 0x58)
	reg_mod_rm_registers(e, a, b)
}

encode_vec_add_8xf32 :: proc(e: ^Emitter, dst, a, b: Register) {
	vex_prefix(e, dst, b, a, 1)
	append(&e.code, 0x58)
	reg_mod_rm_registers(e, dst, b)
}

encode_add_imm :: proc(e: ^Emitter, reg: Register, imm: i64) {
	rex_prefix(e, Register(0), reg)
	aimm := abs(imm)

	if aimm < i64(max(i8)) {
		append(&e.code, 0x83)
		reg_mod_rm_registers(e, Register(0), reg)
		append(&e.code, transmute(u8)i8(imm))
	} else {
		imm32bytes := transmute([4]byte)i32(imm)
		append(&e.code, 0x81) 
		reg_mod_rm_registers(e, Register(0), reg)
		for b in imm32bytes do append(&e.code, b)
	}

}

encode_ret :: proc(e: ^Emitter) {
	append(&e.code, 0xC3)
}

encode_add :: proc(e: ^Emitter, a, b: Register) {
	rex_prefix(e, b, a)
	append(&e.code, 0x01)
	reg_mod_rm_registers(e, b, a)
}

encode_sub :: proc(e: ^Emitter, a, b: Register) {
	rex_prefix(e, b, a)
	append(&e.code, 0x29)
	reg_mod_rm_registers(e, b, a)
}

encode_mul :: proc(e: ^Emitter, a, b: Register) {
	rex_prefix(e, a, b)
	append(&e.code, 0x0F, 0x0AF)
	reg_mod_rm_registers(e, a, b)
}

vex_prefix :: proc(e: ^Emitter, reg, rm, vvvv: Register, map_select: u8, wide:=false, l:u8=1, pp:u8=0) {
	// prolly put x in here at some point
	if (u8(rm)&0x8 == 0) && !wide && map_select == 1 {
		vex2_prefix(e, reg, vvvv, l, pp)
	} else {
		vex3_prefix(e, reg, rm, vvvv, map_select, wide, l, pp)
	}
}

vex3_prefix :: proc(e: ^Emitter, reg, rm, vvvv: Register, map_select: u8, wide:=false, l:u8=1, pp:u8=0) {
	// 11000001
	// prolly put the ~x in the b2 byte
	nx : u8 = 1<<6
	b2 := ((~u8(reg)<<4)&0x80) | nx | ((~u8(rm)<<1)&0x10) | map_select
	b3 : u8 = 0 
	b3 |= (u8(wide) << 7) 
	b3 |=  ((~u8(vvvv))&0xF) << 3
	b3 |=  (l<<2) | pp
	append(&e.code, 0xC4, b2, b3)
}

vex2_prefix :: proc(e: ^Emitter, reg, vvvv: Register, l:u8=1, pp:u8=0) {
	b := ((~u8(reg)<<4)&0x80) | (~u8(vvvv)<<3) | l<<2 | pp
	append(&e.code, 0xC5, b)
}

rex_prefix :: proc(e: ^Emitter, reg, rm: Register, wide:=true) {
	extended_reg := (u8(reg)&0x8) > 0
	extended_rm := (u8(rm)&0x8) > 0
	if extended_reg || extended_rm || wide {
		rex: u8 = 0b0100_0000
		rex |= u8(wide)<<3
		rex |= (u8(reg)&0x8)>>1
		rex |= (u8(rm)&0x8)>>3
		append(&e.code, rex)
	}
}

reg_mod_rm_registers :: proc(e: ^Emitter, reg, rm: Register) {
	b: u8 = 0b11_000_000
	b |= (u8(reg)&0x7) << 3
	b |= u8(rm)&0x7
	append(&e.code, b)
}

import "core:fmt"
main :: proc() {
	e := &Emitter{code = make([dynamic]byte)}

	encode_vec_add_8xf32(e, .XMM0, .XMM1, .XMM12)


	for b in e.code {
		fmt.printf("%02X ", b)
	}
}