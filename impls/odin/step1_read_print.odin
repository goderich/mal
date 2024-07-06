package mal

import "core:fmt"
import "core:os"
import "core:mem/virtual"

import "reader"

READ :: proc(s: string) -> (ast: reader.MalType, ok: bool) {
    return reader.read_str(s)
}

EVAL :: proc(ast: reader.MalType) -> reader.MalType {
    return ast
}

PRINT :: proc(ast: reader.MalType) -> string {
    return reader.pr_str(ast)
}

rep :: proc(s: string) -> (p: string, ok: bool) {
    r := READ(s) or_return
    e := EVAL(r)
    p = PRINT(e)
    return p, true
}

main :: proc() {
    arena: virtual.Arena
    defer virtual.arena_destroy(&arena)
    context.allocator = virtual.arena_allocator(&arena)

    buf: [256]byte
    fmt.println("Welcome to MAL-Odin 0.0.1")

    for {
        fmt.print("user> ")
        n, err := os.read(os.stdin, buf[:])
        if err < 0 {
            // Handle error
            return
        }

        input := string(buf[:n])
        switch input {
        case ",q\n", ",quit\n":
            return
        case "\n":
            continue
        }

        if r, ok := rep(input); ok {
            fmt.println(r)
        }
    }
}
