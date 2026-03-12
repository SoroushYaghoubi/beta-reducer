#+feature dynamic-literals
#+feature using-stmt

package main
import "core:strings"
import "core:os"
import "core:fmt"

EMPTY := EXPR(VAR{' '})

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

reduce :: proc(expr : string) -> (EXPR, bool) {
	if expr == "" {
		return EMPTY, true
	}

	if isAtomic(expr) {
		return VAR{rune(expr[0])}, false
	}

	if expr[0] == '\\' {
		v := rune(expr[1])
		M := expr[3:len(expr)]
		
		if !isAtomic(v) || expr[2] != '.' {
			return EMPTY, true
		}

		M_reduced, err := reduce(M)

		return ABS{ {v},  &M_reduced }, false
	}

	if expr[0] == '(' {
		openning_left : int = 0
		closing_left, err := findClosing(expr, openning_left)
		if err {
			fmt.println("Error while parsins MM expressions: ", expr)
			return EMPTY, true
		}

		openning_right : int = closing_left+1
		closing_right := len(expr)

		L, err1 := reduce(expr[openning_left+1: closing_left-1])		
		R, err2 := reduce(expr[openning_right+1: closing_right-1])
		
		if err1 || err2 {
			fmt.println("Error while parsins MM expressions: ", expr)
			return EMPTY, true
		}

		return APP{ &L, &R }, false
	}

	return EMPTY, false
}

log :: proc(expr : EXPR) {
	switch t in expr {
	case VAR:
		fmt.println(t.x)
	case APP:
		fmt.println(t.L, t.R)
	case ABS:
		fmt.println(t.x, t.M)
	}
}

main :: proc() {
	fmt.println()
	buf: [64]byte

	fmt.print("> ")
	os.read(os.stdin, buf[:])
	code := string(buf[:])
	code = strings.trim_space(code);

	beta_reduced, err := reduce(code)
	log(beta_reduced)

	fmt.println("-> ", )
}

// 
// H E L P E R     F U N C T I O N S
// 

findClosing :: proc (expr : string, start : int) -> (int, bool) {
	if expr[start] != '(' || len(expr) < start+1 {
		return -1, true
	}

	paran_stack : int = 1
	for i in (start+1)..=len(expr) {
		switch expr[i] {
		case '(': 
			paran_stack+=1
		case ')': 
			paran_stack-=1
			if paran_stack == 0  {
				return i, false
			}
		case:
    		continue
		}
	}

	return -1, true
}

isStringAtomic :: proc(c : string) -> bool {
	if len(c)==2 {
		if c[0] >= 'a' && c[0] <= 'z' {
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