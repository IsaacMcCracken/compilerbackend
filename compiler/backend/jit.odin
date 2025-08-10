package backend

import "../frontend"
import "x64"
import vmem "core:mem/virtual"
import "core:fmt"
import rl "vendor:raylib"
import "core:strings"

jit_test :: proc(fn: ^frontend.Fn_Decl) {
	fmt.println("STARTING FUNCTION COMPILATION OF", fn.name)
	fmt.println("Size of Node:", size_of(Node))
	e := &x64.Emitter{code = make([dynamic]byte)}
	g := &Function{}
	graph_builder_init(g)

	to_ir_fn_decl(g, fn)
	// node_walker := make(map[^Node]rl.Vector2)
	// window_viewer(g, &node_walker)

	fmt.println("return", g.stop.inputs[0].inputs[1])

	emit_x64(g, e)


	if len(e.code) > 0 {
		for b, i in e.code {
			fmt.printf("0x%02X ", b)
		}
	
	
		arena := vmem.Arena{}
		err := vmem.arena_init_static(&arena, len(e.code), len(e.code))
		fn_data := make([]byte, len(e.code), vmem.arena_allocator(&arena))
		copy(fn_data, e.code[:])
		vmem.protect(raw_data(fn_data), len(fn_data), {.Execute})
	
		fn := transmute(proc(x: int) -> int)raw_data(fn_data)
		result := fn(60)
		fmt.println("Result:", result)
	}
}



// window_viewer :: proc(f: ^Function, walker: ^map[^Node]rl.Vector2) {
// 	rl.InitWindow(800, 800, "Function")
// 	defer rl.CloseWindow()


// 	rl.SetTargetFPS(60)
// 	for !rl.WindowShouldClose() {
// 		clear_map(walker)
// 		render_function(f)
// 	}
// }

// render_function :: proc(f: ^Function) {
// 	node_rect_draw :: proc(n: ^Node, label: cstring, pos: rl.Vector2, idx: int, col: rl.Color) {
// 		xlen := f32(rl.MeasureText(label, 20))
// 		rec := rl.Rectangle{pos.x, pos.y, xlen, 20}
// 		rl.DrawRectangleRec(rec, col)
// 		rl.DrawTextEx(rl.GetFontDefault(), label, pos, 20, 1, rl.BLACK)
// 	}
// 	render_node :: proc(f: ^Function, w: map[^Node]rl.Vector2, n: ^Node) {
// 		pos, ok := w[n]
// 		if ok do return
// 		#partial switch n.kind {
// 			case .Start:
// 				label := cstring("START")
// 				pos := rl.Vector2{380, 40}
// 				w[n] = pos
// 				node_rect_draw(n, label, pos, 0, rl.DARKPURPLE)
// 				users := get_node_users(n)
// 				for wuser, i in users {
// 					user, slot := unwrap_user(wuser)
// 					render_node(f, w, user)
// 					cpos := w[user]
// 					rl.DrawLineV(pos, cpos, rl.BLACK)
// 				}
// 			case .Return:
// 				label := cstring("return")
// 				pos := node_rect_draw
// 			case .Proj:
// 				label := cstring("arg")
// 				ppos := w[n.inputs[0]]
// 				node_rect_draw(n, label, ppos + , idx, rl.YELLOW)
// 			case .Const:
// 				label: cstring
// 				#partial switch n.type.kind {
// 					case .I64:
// 						temp := fmt.tprintf("%d\x00", n.vint)
// 						label = strings.unsafe_string_to_cstring(temp)
// 				}
// 				return node_rect_draw(p, n, label, parent_pos, idx, rl.BLUE)
// 			case: fmt.println(n.kind)
// 		}

// 		return {0, 0}
// 	}
// 	rl.BeginDrawing()
// 	rl.ClearBackground(rl.WHITE)
// 	render_node(f, nil, f.start, {}, 0)
// 	rl.EndDrawing()
// }