package mal

import "core:fmt"
import "core:os"
import "core:mem/virtual"

import "reader"

Ast :: reader.Ast
Fn :: proc(..Ast) -> Ast
Env :: map[reader.Symbol]Fn

Eval_Error :: enum {
    none,
    not_a_function,
}

Error :: union {
    reader.Error,
    Eval_Error,
}

READ :: proc(s: string) -> (Ast, reader.Error) {
    ast, err := reader.read_str(s)
    return ast, err
}

EVAL :: proc(ast: Ast, env: Env) -> (Ast, Eval_Error) {
    return eval_ast(ast, env)
}

eval_ast :: proc(input: Ast, env: Env) -> (res: Ast, err: Eval_Error) {
    #partial switch v in input {
    case reader.List:
        if len(v) == 0 do return v, .none

        list: [dynamic]Ast
        for elem in v {
            evaled := EVAL(elem, env) or_return
            append(&list, evaled)
        }
        return apply_fn(list[:], env)
    }
    return input, err
}

apply_fn :: proc(list: []Ast, env: Env) -> (res: Ast, err: Eval_Error) {
    fst := list[0].(reader.Atom).(reader.Symbol)
    f := env[fst]
    return f(..list[1:]), err
}

create_env :: proc() -> (env: Env) {
    env["+"] = proc(xs: ..Ast) -> Ast {
        acc := 0
        for x in xs {
            n := x.(reader.Atom).(int)
            acc += n
        }
        return reader.Atom(acc)
    }
    return env
}

PRINT :: proc(ast: Ast) -> string {
    return reader.pr_str(ast)
}

rep :: proc(s: string) -> (p: string, err: Error) {
    r := READ(s) or_return
    env := create_env()
    e := EVAL(r, env) or_return
    p = PRINT(e)
    return p, err
}

main :: proc() {
    arena: virtual.Arena
    defer virtual.arena_destroy(&arena)
    context.allocator = virtual.arena_allocator(&arena)

    buf: [256]byte
    fmt.println("Welcome to MAL-Odin 0.0.2")

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

        r, rep_err := rep(input)
        if rep_err != nil {
            switch rep_err {
            case .unbalanced_parentheses:
                fmt.println("Error: unbalanced parentheses.")
            case .unbalanced_quotes:
                fmt.println("Error: unbalanced quotes.")
            case .parse_int_error:
                fmt.println("Error: parse int error.")
            }
        } else {
            fmt.println(r)
        }
    }
}
