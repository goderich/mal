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
    // Declaring variables for use with TCO
    ast, env := input, outer_env
    // Main TCO loop. Any `continue` inside is a tailcall.
    for {
        if body, ok := ast.(List); ok {
            if len(body) == 0 do return body, true

            // Special forms:
            switch fst, ok := body[0].(Symbol); fst {
            case "def!":
                return eval_def(body, env)
            case "let*":
                ast, env = eval_let(body, env) or_return
                continue
            case "do":
                ast = eval_do(body, env) or_return
                continue
            case "if":
                ast = eval_if(body, env) or_return
                continue
            case "fn*":
                return eval_fn(body, env)
            }

            // Normal function evaluation
            evaled := eval_ast(body, env) or_return
            args := evaled.(List)[1:]
            // Needs to be passed as `&fn` to get
            // addressable semantics (as suggested by the compiler),
            // i.e. so that I can modify its contents.
            #partial switch &fn in evaled.(List)[0] {
                case Core_Fn:
                ast, ok = fn(..cast([]MalType)args)
                if !ok {
                    fmt.println("Exception!")
                    return nil, false
                }
                return ast, true

                case Closure:
                ast, env = eval_closure(&fn, args)
                continue

                case:
                fmt.printfln("Error: '%s' is not a function.", body[0])
                return ast, false
            }
        } else {
            // Not a function or special form
            return eval_ast(ast, env)
        }

    }
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

eval_let :: proc(ast: List, outer_env: ^Env) -> (body: MalType, env: ^Env, ok: bool) {
    let_env := new(Env)
    let_env.outer = outer_env

    bindings := to_list(ast[1]) or_return

    // Iterate over pairs, adding bindings to the environment.
    for i := 0; i < len(bindings); i += 2 {
        name := bindings[i].(Symbol)
        val := EVAL(bindings[i+1], let_env) or_return
        types.env_set(let_env, name, val)
    }

    // Return body and the new environment
    return ast[2], let_env, true

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
    third := ast[3] if len(ast) == 4 else nil

    bool_cond, is_bool := cond.(bool)
    if (is_bool && !bool_cond) || cond == nil {
        return third, true
    }
    return ast[2], true
}

eval_do :: proc(ast: List, outer_env: ^Env) -> (res: MalType, ok: bool) {
    for i in 1..<(len(ast) - 1) {
        res = EVAL(ast[i], outer_env) or_return
    }
    return ast[len(ast) - 1], true
}

eval_fn :: proc(ast: List, outer_env: ^Env) -> (fn: Closure, ok: bool) {
    // Capture parameters
    if params, ok := lib.unpack_seq(ast[1]); ok {
        for param in params do append(&fn.params, param.(Symbol))
    } else {
        fmt.println("Error: the second member of a fn* expression must be a vector or list.")
        return fn, false
    }

    // Create function environment
    fn.env = new(Env)^
    fn.env.outer = outer_env

    fn.ast = &ast[2]
    return fn, true
}

eval_closure :: proc(fn: ^Closure, args: List) -> (ast: MalType, env: ^Env) {
    for i in 0..<len(fn.params) {
        // "Rest" params with '&'
        if fn.params[i] == "&" {
            rest_params := fn.params[i+1]
            rest_vals := args[i:]
            types.env_set(&fn.env, rest_params, rest_vals)
            break
        }
        // Regular args
        types.env_set(&fn.env, fn.params[i], args[i])
    }

    return fn.ast^, &fn.env
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
    fmt.println("Welcome to MAL-Odin 0.0.5")
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
