package backend

import "core:fmt"

// print_graph :: proc(g: ^Function) {
// 	recurse :: proc(n: ^Node, i: ^int) {
// 		switch n.kind {
// 			case .Return:
// 				recurse(n.inputs[1])
// 			case .Const:
// 				fmt.printfln("%%%d = %d", i, n.vint)
// 			case .Add
// 				fmt.printfln("add %%%d, %%%d",)
// 		}
// 	}

// 	i := 0
// 	for output in get_node_outputs(g.start) {
// 		if output.kind == .Return {
// 			recurse(g, output)
// 		}
// 	}
// }