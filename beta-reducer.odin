#+feature dynamic-literals
#+feature using-stmt

package main
import "core:strings"
import "core:os"
import "core:fmt"
import "core:unicode"

MOD_UPPER :: false
MOD_INTERNALS :: false
MOD_QUIT :: true

format :: proc(r : rune) -> rune {
	when MOD_UPPER {
		return unicode.to_upper(r)
	} else {
		return r
	}
}

/*
	# Only supporing these runes rn:
		a b c ... z
		. ( )

	# λ-expressions
		a, b, c, ... y, z
		(\a.M)
		(M M)
*/

APP :: struct {
	L : ^EXPR,
	R : ^EXPR,
}

VAR :: struct {
	x : rune,
}

ABS :: struct {
	x: VAR,
	M: ^EXPR,
}

EXPR :: union {
	APP,
	VAR,
	ABS,
}

parse :: proc(expr : string) -> EXPR {
	if len(expr) == 1 {
		v_ := format(cast(rune)expr[0])
		return VAR{v_}
	}

	// ( \ x . M )
	//     ^   ^
	//     2    4
	if expr[1] == '\\' {
		M := new(EXPR)
		M^ = parse(expr[4:len(expr)-1])

		v_ := format(cast(rune)expr[2])
		return ABS{VAR{ v_ }, M}
	}

	switch expr[1] {
	// ( M          N )
	//   ^           ^
	//   1   M_closing+1
	case '(':
		M_closing := findClosing(expr, 1)
		M := new(EXPR)
		N := new(EXPR)
		M^ = parse(expr[1:M_closing+1])
		N^ = parse(expr[M_closing+1:len(expr)-1])
		return APP{M, N}
	// ( x   M )
	//   ^   ^
	//   1    2
	case:
		v_ := format(cast(rune)expr[1])
		v := new(EXPR)
		v^ = VAR{ v_ }
		M := new(EXPR)
		M^ = parse(expr[2:len(expr)-1])
		return APP{v, M}
	}
	
	// unsupported case
	fmt.eprintfln("Couldn't parse lambda expression.")
	return VAR{' '}
}

reduce :: proc(expr : EXPR) -> EXPR {
	#partial switch e in expr {
	case ABS:
		M := new(EXPR)
		M^ = reduce(e.M^)
		return EXPR(ABS{e.x, M})
	case APP:
		switch t in e.L {
		case ABS:
			return substitute(t.M^, t.x.x, reduce(e.R^))
		case VAR:
			M := new(EXPR)
			N := new(EXPR)
			M^ = t
			N^ = reduce(e.R^)
			return EXPR(APP{M, N})
		case APP:
			L := new(EXPR)
			R := new(EXPR)
			L^ = reduce(e.L^)
			R^ = reduce(e.R^)
			return EXPR(APP{L, R})
		}
	}

	return expr
}

// ((\x.(\x.(\y.a)))m)
substitute :: proc(expr : EXPR, param : rune, sub_expr : EXPR) -> EXPR {
	switch e in expr {
	case VAR: 
		if e.x == param {
			return sub_expr
		}
	case APP:
		L_substituted := new(EXPR)
		R_substituted := new(EXPR)
		L_substituted^ = substitute(e.L^, param, sub_expr)
		R_substituted^ = substitute(e.R^, param, sub_expr)
		return EXPR(APP{ L_substituted, R_substituted })
	case ABS:
		if e.x.x == param {
			return expr
		}
		M_substituted := new(EXPR)
		M_substituted^ = substitute(e.M^, param, sub_expr)
		return EXPR(ABS{ e.x, M_substituted })
	}

	return expr
}

main :: proc() {
	fmt.println()
	buf: [64]byte

	for {
		fmt.print("> ")
		n, _ := os.read(os.stdin, buf[:])
		expr := string(buf[:n])
		expr = strings.trim_space(expr);
		when MOD_QUIT {
			if expr == "q" {
				return
			}
		}

		parsed_expr := parse(expr)

		fmt.print("-> ")
		log(parsed_expr)
		fmt.println()
		reduced_expr := reduce(parsed_expr)
		fmt.print("-> ")
		log(reduced_expr)
		when MOD_INTERNALS {
			fmt.println("-> ", parsed_expr)
		}
		fmt.println()
		fmt.println()
	}
}

// 
// H E L P E R     F U N C T I O N S
// 

log :: proc(expr : EXPR) {
	switch t in expr {
	case VAR:
		fmt.print(t.x)
	case APP:
		fmt.print('(')
		log(t.L^)
		fmt.print(' ')
		log(t.R^)
		fmt.print(')')
	case ABS:
		fmt.print("(\\")
		log(t.x)
		fmt.print('.')
		log(t.M^)
		fmt.print(")")
	}
}

findClosing :: proc (expr : string, start : int) -> int {
	if expr[start] != '(' || len(expr) < start+1 {
		return -1
	}

	paran_stack : int = 1
	for i in (start+1)..=len(expr) {
		switch expr[i] {
		case '(': 
			paran_stack+=1
		case ')': 
			paran_stack-=1
			if paran_stack == 0  {
				return i
			}
		case:
    		continue
		}
	}

	return -1
}

isStringAtomic :: proc(s: string) -> bool {
	if len(s)==1 {
		if s[0] >= 'a' && s[0] <= 'z' {
			return true
		}
	}

	return false
}

isRuneAtomic :: proc(c : rune) -> bool {
	if c >= 'a' && c <= 'z' {
		return true
	}

	return false
}

isAtomic :: proc { isStringAtomic, isRuneAtomic }
