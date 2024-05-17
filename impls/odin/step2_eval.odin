package mal

import "core:fmt"
import "core:os"
import "core:mem/virtual"

import "reader"

MalType :: reader.MalType
Reader_Error :: reader.Error
Fn :: proc(..MalType) -> MalType
Env :: map[reader.Symbol]Fn

Eval_Error :: enum {
    none,
    not_a_symbol,
    not_a_function,
}

Error :: union {
    Reader_Error,
    Eval_Error,
}

READ :: proc(s: string) -> (MalType, reader.Error) {
    ast, err := reader.read_str(s)
    return ast, err
}

EVAL :: proc(input: MalType, env: ^Env) -> (res: MalType, err: Eval_Error) {
    #partial switch ast in input {
    case reader.List:
        if len(ast) == 0 do return ast, .none
        evaled := eval_ast(ast, env) or_return
        list := evaled.(reader.List)
        return apply_fn(list, env)
    }

    return eval_ast(input, env)
}

eval_ast :: proc(input: MalType, env: ^Env) -> (res: MalType, err: Eval_Error) {
    #partial switch ast in input {
    case reader.List:
        list: [dynamic]MalType
        for elem in ast {
            evaled := EVAL(elem, env) or_return
            append(&list, evaled)
        }
        return reader.List(list[:]), .none

    case reader.Vector:
        list: [dynamic]MalType
        for elem in ast {
            evaled := EVAL(elem, env) or_return
            append(&list, evaled)
        }
        return reader.Vector(list[:]), .none

    case reader.Hash_Map:
        m := make(map[^MalType]MalType)
        for k, v in ast {
            evaled := EVAL(v, env) or_return
            m[k] = evaled
        }
        return reader.Hash_Map(m), .none
    }

    return input, .none
}

apply_fn :: proc(ast: reader.List, env: ^Env) -> (res: MalType, err: Eval_Error) {
    list := cast([]MalType)ast
    fst := list[0]
    sym, ok := fst.(reader.Symbol)
    if !ok do return nil, .not_a_symbol
    f, exist := env[sym]
    if !exist do return nil, .not_a_function
    return f(..list[1:]), err
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

rep :: proc(s: string) -> (p: string, err: Error) {
    r := READ(s) or_return
    env := create_env()
    e := EVAL(r, &env) or_return
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
            case Reader_Error.unbalanced_parentheses:
                fmt.println("Error: unbalanced parentheses.")
            case Reader_Error.unbalanced_quotes:
                fmt.println("Error: unbalanced quotes.")
            case Reader_Error.parse_int_error:
                fmt.println("Error: parse int error.")
            case Eval_Error.not_a_symbol:
                fmt.println("Error: the first member of a list must be a symbol.")
            case Eval_Error.not_a_function:
                fmt.println("Error: symbol is not a function.")
            }
        } else {
            fmt.println(r)
        }
    }
}
