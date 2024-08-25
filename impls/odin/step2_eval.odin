package mal

import "core:fmt"
import "core:os"
import "core:mem/virtual"

import "reader"
import "types"

MalType :: types.MalType
List :: types.List
Vector :: types.Vector
Symbol :: types.Symbol
Keyword :: types.Keyword
Hash_Map :: types.Hash_Map

Fn :: proc(..MalType) -> MalType
Env :: map[reader.Symbol]Fn

READ :: proc(s: string) -> (ast: MalType, ok: bool) {
    return reader.read_str(s)
}

EVAL :: proc(input: MalType, env: ^Env) -> (res: MalType, ok: bool) {
    #partial switch ast in input {
    case List:
        if len(ast.data) == 0 do return ast, true
        evaled := eval_ast(ast, env) or_return
        list := evaled.(List)
        return apply_fn(list, env)
    }

    return eval_ast(input, env)
}

eval_ast :: proc(input: MalType, env: ^Env) -> (res: MalType, ok: bool) {
    #partial switch ast in input {
    case List:
        list: [dynamic]MalType
        for elem in ast.data {
            evaled := EVAL(elem, env) or_return
            append(&list, evaled)
        }
        return types.to_list(list), true

    case Vector:
        list: [dynamic]MalType
        for elem in ast.data {
            evaled := EVAL(elem, env) or_return
            append(&list, evaled)
        }
        return types.to_vector(list), true

    case Hash_Map:
        m := new(Hash_Map)
        for k, v in ast.data {
            evaled := EVAL(v, env) or_return
            m.data[k] = evaled
        }
        return m^, true
    }

    return input, true
}

apply_fn :: proc(ast: List, env: ^Env) -> (res: MalType, ok: bool) {
    fst := ast.data[0]
    sym, s_ok := fst.(Symbol)
    if !s_ok {
        fmt.printfln("Error: {:v} is not a symbol.", fst)
        return nil, false
    }
    f, exist := env[sym]
    if !exist {
        fmt.printfln("Error: {:v} is not defined.", sym)
        return nil, false
    }
    return f(..ast.data[1:]), true
}

create_env :: proc() -> (env: Env) {
    env["+"] = proc(xs: ..MalType) -> MalType {
        acc := 0
        for x in xs {
            n := x.(int)
            acc += n
        }
        return acc
    }

    env["*"] = proc(xs: ..MalType) -> MalType {
        acc := 1
        for x in xs {
            n := x.(int)
            acc *= n
        }
        return acc
    }

    env["-"] = proc(xs: ..MalType) -> MalType {
        acc := xs[0].(int)
        rest := xs[1:]
        for x in rest {
            n := x.(int)
            acc -= n
        }
        return acc
    }

    env["/"] = proc(xs: ..MalType) -> MalType {
        acc := xs[0].(int)
        rest := xs[1:]
        for x in rest {
            n := x.(int)
            acc /= n
        }
        return acc
    }

    return env
}

PRINT :: proc(ast: MalType) -> string {
    return reader.pr_str(ast)
}

rep :: proc(s: string) -> (p: string, ok: bool) {
    r := READ(s) or_return
    env := create_env()
    e := EVAL(r, &env) or_return
    p = PRINT(e)
    return p, true
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


        if r, ok := rep(input); ok {
            fmt.println(r)
        }
    }
}
