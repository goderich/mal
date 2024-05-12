package step1_read_print

import "core:fmt"
import "core:os"

import "reader"

READ :: proc(s: string) -> (reader.Ast, reader.Error) {
    ast, err := reader.read_str(s)
    return ast, err
}

EVAL :: proc(ast: reader.Ast) -> reader.Ast {
    return ast
}

PRINT :: proc(ast: reader.Ast) -> string {
    return reader.pr_str(ast)
}

rep :: proc(s: string) -> (p: string, err: reader.Error) {
    r := READ(s) or_return
    e := EVAL(r)
    p = PRINT(e)
    return p, .none
}

main :: proc() {
    buf: [256]byte
    fmt.println("Welcome to MAL-Odin 0.0.1")

    for {
        fmt.print("user> ")
        n, err := os.read(os.stdin, buf[:])
        if err < 0 {
            // Handle error
            return
        }

        r, rep_err := rep(string(buf[:n]))
        if rep_err != nil {
            #partial switch rep_err {
            case .unbalanced_parentheses:
                fmt.println("Error: unbalanced parentheses.")
            }
        } else {
            fmt.println(r)
        }
    }
}
