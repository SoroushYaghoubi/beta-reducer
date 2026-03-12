#+feature dynamic-literals
#+feature using-stmt

package main
import "core:strings"
import "core:os"
import "core:fmt"
import "core:unicode"

MOD_UPPER :: false
MOD_INTERNALS :: false

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
		a, b, c, ..., z
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

	// case 1:
		// ( M          N )
		//   ^           ^
		//   1   M_closing+1
	// case 2:
		// ( x   M )
		//   ^   ^
		//   1    2
	switch expr[1] {
	case '(':
		M_closing := findClosing(expr, 1)
		M := new(EXPR)
		N := new(EXPR)
		M^ = parse(expr[1:M_closing+1])
		N^ = parse(expr[M_closing+1:len(expr)-1])
		return APP{M, N}
	case:
		v_ := format(cast(rune)expr[1])
		v := new(EXPR)
		v^ = VAR{ v_ }
		M := new(EXPR)
		M^ = parse(expr[2:len(expr)-1])
		return APP{v, M}
	}

	// unsupported case
	fmt.eprintfln("Couldn't match any lambda expressions.")
	return VAR{' '}
}

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

main :: proc() {
	fmt.println()
	buf: [64]byte


	for {
		fmt.print("> ")
		n, _ := os.read(os.stdin, buf[:])
		code := string(buf[:n])
		code = strings.trim_space(code);
		if code == "q" {
			return
		}

		beta_reduced := parse(code)

		fmt.print("-> ")
		log(beta_reduced)
		fmt.println()
		when MOD_INTERNALS {
			fmt.println("-> ", beta_reduced)
		}
		fmt.println()
	}
}

// 
// H E L P E R     F U N C T I O N S
// 

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
