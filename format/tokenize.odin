package format


Token_Kind :: enum u32 {
	EOF,
	Invalid,
	Open,
	Close,
	Tag,
	Identifier
}

Token :: struct {
	kind: Token_Kind,
	start, end: u32	
}

tokenize :: proc(tokens: ^[dynamic]Token, src: []byte) {
	curr, prev: u32

	for curr < u32(len(src)) {
		ch := src[curr]
		switch ch {
		case '(':
			curr += 1
			append(tokens, Token{kind = .Open, start = prev, end = curr})
		case ')':
			curr += 1
			append(tokens, Token{kind = .Close, start = prev, end = curr})
		case '@':
			tag: for curr < u32(len(src)) {
				ch := src[curr] 
				switch ch {
					case 'a'..='z', 'A'..='Z', '0'..='9', '!', '#'..='&', '*'..='/', ':'..='?', '_', '^', '|', '@':
						curr += 1
					case:
						break tag
				}
			}
			append(tokens, Token{kind = .Tag, start = prev, end = curr})
		case 'a'..='z', 'A'..='Z', '0'..='9', '!', '#'..='&', '*'..='/', ':'..='?', '_', '^', '|':
			identifier: for curr < u32(len(src)) {
				ch := src[curr]
				switch ch {
					case 'a'..='z', 'A'..='Z', '0'..='9', '!', '#'..='&', '*'..='/', ':'..='?', '_', '^', '|':
						curr += 1
					case:
						break identifier
				}
			}

			append(tokens, Token{kind = .Identifier, start = prev, end = curr})
		case: 
			curr += 1
		}
		

		prev = curr
	}



}
