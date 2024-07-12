package mal

import "core:os"
import "core:mem/virtual"
import "core:fmt"
import "core:strings"

import "types"
import "reader"
import "core"

MalType :: types.MalType
List :: types.List
Vector :: types.Vector
Symbol :: types.Symbol
Keyword :: types.Keyword
Hash_Map :: types.Hash_Map
Core_Fn :: types.Core_Fn

Env :: types.Env

// Global environment created here for now.
main_env := create_env()

READ :: proc(s: string) -> (ast: MalType, ok: bool) {
    return reader.read_str(s)
}

// Special forms and function application
EVAL :: proc(input: MalType, repl_env: ^Env) -> (res: MalType, ok: bool) {
    #partial switch ast in input {
    case List:
        if len(ast) == 0 do return ast, true

        fst, ok := ast[0].(Symbol)
        if !ok {
            fmt.println("Error: the first member of a list must be a symbol.")
            return nil, false
        }

        // Special forms:
        switch fst {
        case "def!":
            return eval_def(ast, repl_env)
        case "let*":
            return eval_let(ast, repl_env)
        }

        // Normal function evaluation
        evaled := eval_ast(ast, repl_env) or_return
        return apply_fn(evaled.(List), repl_env)
    }

    return eval_ast(input, repl_env)
}

// Evaluation of symbols and data structures
eval_ast :: proc(input: MalType, repl_env: ^Env) -> (res: MalType, ok: bool) {
    #partial switch ast in input {
    case List:
        list: [dynamic]MalType
        for elem in ast {
            evaled := EVAL(elem, repl_env) or_return
            append(&list, evaled)
        }
        return List(list[:]), true

    case Vector:
        list: [dynamic]MalType
        for elem in ast {
            evaled := EVAL(elem, repl_env) or_return
            append(&list, evaled)
        }
        return Vector(list[:]), true

    case Hash_Map:
        m := make(map[^MalType]MalType)
        for k, v in ast {
            evaled := EVAL(v, repl_env) or_return
            m[k] = evaled
        }
        return m, true

    case Symbol:
        val, ok := types.env_get(repl_env, ast)
        if ok {
            return val, true
        } else {
            fmt.printfln("Error: symbol '%s' not found", ast)
            return nil, false
        }
    }

    return input, true
}

eval_def :: proc(ast: List, repl_env: ^Env) -> (res: MalType, ok: bool) {
    sym := ast[1].(Symbol)
    // Evaluate the expression to get symbol value
    val := EVAL(ast[2], repl_env) or_return
    // Set environment variable
    types.env_set(repl_env, sym, val)
    // Retrieve variable
    return types.env_get(repl_env, sym)
}

eval_let :: proc(ast: List, repl_env: ^Env) -> (res: MalType, ok: bool) {
    let_env: Env
    let_env.outer = repl_env

    bindings: []MalType
    #partial switch t in ast[1] {
    case List:
        bindings = cast([]MalType)t
    case Vector:
        bindings = cast([]MalType)t
    case:
        fmt.println("Error: the second member of a let* expression must be a list or a vector.")
        return nil, false
    }

    if len(bindings) % 2 != 0 {
        fmt.println("Error: the list of bindings in let* must have an even number of elements.")
        return nil, false
    }

    // Iterate over pairs, adding bindings to the environment.
    for i := 0; i < len(bindings); i += 2 {
        name := bindings[i].(Symbol)
        val := EVAL(bindings[i+1], &let_env) or_return
        types.env_set(&let_env, name, val)
    }
    // Evaluate final expression
    return EVAL(ast[2], &let_env)
}

apply_fn :: proc(ast: List, repl_env: ^Env) -> (res: MalType, ok: bool) {
    // Extract function
    f, f_ok := ast[0].(Core_Fn)
    if !f_ok {
        fmt.printfln("Error: '%s' is not a function.", ast[0])
        return nil, false
        }

    // Apply function and return the result.
    return f(..cast([]MalType)ast[1:]), true
}

create_env :: proc() -> (repl_env: Env) {
    for name, fn in core.make_ns() {
        types.env_set(&repl_env, name, Core_Fn(fn))
    }

    return repl_env
}

PRINT :: proc(ast: MalType) -> string {
    return reader.pr_str(ast)
}

rep :: proc(s: string) -> (p: string, ok: bool) {
    r := READ(s) or_return
    e := EVAL(r, &main_env) or_return
    p = PRINT(e)
    return p, true
}

main :: proc() {
    arena: virtual.Arena
    defer virtual.arena_destroy(&arena)
    context.allocator = virtual.arena_allocator(&arena)

    buf: [256]byte
    fmt.println("Welcome to MAL-Odin 0.0.3")

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
