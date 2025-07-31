package backend


import "x64"
import "core:fmt"


reg_args := [?]x64.Register{.RCX, .RDX, .R8, .R9}
@(private="file") volatile_registers := [?]x64.Register{
	.RAX, .RCX, .RDX, .RSI, .RDI, .R8, .R9, .R10, .R11
}

reg_pool := [len(volatile_registers)]u8{}
reg_len := 0





emit_x64 :: proc(f: ^Function, e: ^x64.Emitter) {
	recurse :: proc(e: ^x64.Emitter, n: ^Node, i: ^int) -> x64.Register {
		assert(i^ < len(reg_pool))
		#partial switch n.kind {
			case .Return:
				reg := recurse(e, n.inputs[1], i)
				if reg != .RAX {
					x64.encode_reg_mov(e, .RAX, reg)
				}
				x64.encode_ret(e)
				return reg
			case .Add:
				if n.inputs[0].kind == .Proj && n.inputs[1].kind == .Const {
					arg := n.inputs[0]
					reg := reg_args[arg.vint]
					imm := n.inputs[1].vint
					x64.encode_add_imm(e, reg, imm)
					return reg
				} else {
					lhs := recurse(e, n.inputs[0], i)
					i^ += 1
					rhs := recurse(e, n.inputs[1], i)
					i^ -= 1
					x64.encode_add(e, lhs, rhs)
					return lhs
				}
			case .Mul:
				if n.inputs[0].kind == .Proj && n.inputs[1].kind == .Const {
					arg := n.inputs[0]
					reg := reg_args[arg.vint]
					imm := n.inputs[1].vint
					x64.encode_mul_imm(e, reg, reg, imm)
					return reg
				} else {
					lhs := recurse(e, n.inputs[0], i)
					i^ += 1
					rhs := recurse(e, n.inputs[1], i)
					i^ -= 1
					x64.encode_mul(e, lhs, rhs)
					return lhs
				}

			case .Sub:
				lhs := recurse(e, n.inputs[0], i)
				i^ += 1
				rhs := recurse(e, n.inputs[1], i)
				i^ -= 1
				x64.encode_sub(e, lhs, rhs)
				return lhs
			case .Const:
				// reg := reg_pool[i^]
				reg := x64.Register.RAX
				x64.encode_load_imm(e, reg, n.vint)
				return reg
			case .Proj:
				return reg_args[n.vint]
			case .If:
				cond := n.inputs[1]
				#partial switch cond.kind {
					case .Equals:
					case .Less_Than:
					case .Less_Than_Equal:
					case .Greater_Than:
					case .Greater_Than_Equal:
					case:
						fmt.panicf("\n\t %v is not a supported branch", cond.kind)
				}
			case .Equals, .Less_Than, .Less_Than_Equal, .Greater_Than, .Greater_Than_Equal:
				if n.inputs[0].kind == .Proj && n.inputs[1].kind == .Const {
					lhs := recurse(e, n.inputs[0], i)
					x64.encode_cmp_imm(e, lhs, n.inputs[1].vint)
				} else {
					lhs := recurse(e, n.inputs[0], i)
					i^ += 1
					rhs := recurse(e, n.inputs[1], i)
					i^ -= 1
					x64.encode_cmp(e, lhs, rhs)
				}
			case:
				fmt.panicf("Error: got %v", n.kind)
		}

		return .RAX
	}

	i := 0
	// user, slot := unwrap_user(f.start.users[0])
	for control := f.first; control.kind != .Return; control = get_next_control_node(control) {
		recurse(e, control, &i)
	}
}

get_next_control_node :: proc(n: ^Node) -> (ctrl: ^Node) {
	wusers := get_node_users(n)
	for wuser in wusers {
		user, slot := unwrap_user(wuser)
		if user != nil && user.type.kind == .Control do return user
	}

	return
}