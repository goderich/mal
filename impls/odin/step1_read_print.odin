package step1_read_print

import "core:fmt"
import "core:os"

import "reader"

READ :: proc(s: string) -> reader.Ast {
    ast := reader.read_str(s)
    return ast
}

EVAL :: proc(ast: reader.Ast) -> reader.Ast {
    return ast
}

PRINT :: proc(ast: reader.Ast) -> string {
    return reader.pr_str(ast)
}

rep :: proc(s: string) -> string {
    r := READ(s)
    e := EVAL(r)
    p := PRINT(e)
    return p
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
        r := rep(string(buf[:n]))
        fmt.println(r)
    }
}
