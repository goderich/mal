package mal

import "core:os"
import "core:mem/virtual"
import "core:fmt"

import "types"
import "reader"
import "core"
import "lib"

MalType :: types.MalType
List :: types.List
Vector :: types.Vector
Symbol :: types.Symbol
Keyword :: types.Keyword
Hash_Map :: types.Hash_Map
Core_Fn :: types.Core_Fn
Closure :: types.Closure

Env :: types.Env

// Global environment created here for now.
main_env := create_env()

READ :: proc(s: string) -> (ast: MalType, ok: bool) {
    return reader.read_str(s)
}

// Special forms and function application
EVAL :: proc(input: MalType, outer_env: ^Env) -> (res: MalType, ok: bool) {
    #partial switch ast in input {
    case List:
        if len(ast) == 0 do return ast, true

        // Special forms:
        fst, ok := ast[0].(Symbol)
        switch fst {
        case "def!":
            return eval_def(ast, outer_env)
        case "let*":
            return eval_let(ast, outer_env)
        case "do":
            return eval_do(ast, outer_env)
        case "if":
            return eval_if(ast, outer_env)
        case "fn*":
            return eval_closure(ast, outer_env)
        }

        // Normal function evaluation
        evaled := eval_ast(ast, outer_env) or_return
        res, ok = apply_fn(evaled.(List))
        if !ok {
            fmt.printfln("Error: '%s' is not a function.", ast[0])
            return nil, false
        }
        return res, true
    }

    return eval_ast(input, outer_env)
}

// Evaluation of symbols and data structures
eval_ast :: proc(input: MalType, outer_env: ^Env) -> (res: MalType, ok: bool) {
    #partial switch ast in input {
    case List:
        list: [dynamic]MalType
        for elem in ast {
            evaled := EVAL(elem, outer_env) or_return
            append(&list, evaled)
        }
        return List(list[:]), true

    case Vector:
        list: [dynamic]MalType
        for elem in ast {
            evaled := EVAL(elem, outer_env) or_return
            append(&list, evaled)
        }
        return Vector(list[:]), true

    case Hash_Map:
        m := make(map[^MalType]MalType)
        for k, v in ast {
            evaled := EVAL(v, outer_env) or_return
            m[k] = evaled
        }
        return m, true

    case Symbol:
        if val, ok := types.env_get(outer_env, ast); ok {
            return val, true
        } else {
            fmt.printfln("Error: symbol '%s' not found", ast)
            return nil, false
        }
    }

    return input, true
}

eval_def :: proc(ast: List, outer_env: ^Env) -> (res: MalType, ok: bool) {
    sym := ast[1].(Symbol)
    // Evaluate the expression to get symbol value
    val := EVAL(ast[2], outer_env) or_return
    // Set environment variable
    types.env_set(outer_env, sym, val)
    // Retrieve variable
    return types.env_get(outer_env, sym)
}

eval_let :: proc(ast: List, outer_env: ^Env) -> (res: MalType, ok: bool) {
    let_env := new(Env)
    let_env.outer = outer_env

    bindings := to_list(ast[1]) or_return

    // Iterate over pairs, adding bindings to the environment.
    for i := 0; i < len(bindings); i += 2 {
        name := bindings[i].(Symbol)
        val := EVAL(bindings[i+1], let_env) or_return
        types.env_set(let_env, name, val)
    }
    // Evaluate final expression
    return EVAL(ast[2], let_env)

    // Unpacking list or vector, error handling
    to_list :: proc(ast: MalType) -> (res: []MalType, ok: bool) {
        binds, binds_ok := lib.unpack_seq(ast)

        if !binds_ok {
            fmt.println("Error: the second member of a let* expression must be a list or a vector.")
            return nil, false
        }

        if len(binds) % 2 != 0 {
            fmt.println("Error: the list of bindings in let* must have an even number of elements.")
            return nil, false
        }

        return binds, true
    }
}

eval_if :: proc(ast: List, outer_env: ^Env) -> (res: MalType, ok: bool) {
    cond := EVAL(ast[1], outer_env) or_return
    // If third element is missing, it defaults to nil
    third:= ast[3] if len(ast) == 4 else nil

    is_true, is_bool := cond.(bool)
    if (is_bool && !is_true) || cond == nil {
        return EVAL(third, outer_env)
    }
    return EVAL(ast[2], outer_env)
}

eval_do :: proc(ast: List, outer_env: ^Env) -> (res: MalType, ok: bool) {
    for i in 1..<len(ast) {
        res = EVAL(ast[i], outer_env) or_return
    }
    return res, true
}

eval_closure :: proc(ast: List, outer_env: ^Env) -> (fn: Closure, ok: bool) {
    // Capture args
    if params, ok := lib.unpack_seq(ast[1]); ok {
        for param in params do append(&fn.params, param.(Symbol))
    } else {
        fmt.println("Error: the second member of a fn* expression must be a vector or list.")
    }

    // Create function environment
    fn.env = new(Env)^
    fn.env.outer = outer_env

    fn.ast = &ast[2]
    return fn, true
}

apply_fn :: proc(list: List) -> (res: MalType, ok: bool) {
    // Extract function
    fst := list[0]
    f, f_ok := fst.(Core_Fn)
    if !f_ok do return apply_closure(list)

    // Apply function and return the result.
    return f(..cast([]MalType)list[1:]), true
}

apply_closure :: proc(list: List) -> (res: MalType, ok: bool) {
    // Get the address of the first element,
    // which should be a closure.
    f, f_ok := &list[0].(Closure)
    if !f_ok do return nil, false

    for i in 0..<len(f.params) {
        // "Rest" params with '&'
        if f.params[i] == "&" {
            rest_params := f.params[i+1]
            rest_vals := List(list[i+1:])
            types.env_set(&f.env, rest_params, rest_vals)
            break
        }
        // Regular args
        types.env_set(&f.env, f.params[i], list[i+1])
    }

    return EVAL(f.ast^, &f.env)
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
    fmt.println("Welcome to MAL-Odin 0.0.4")
    // Define `not` using MAL
    rep("(def! not (fn* (a) (if a false true)))")

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
