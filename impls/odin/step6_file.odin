package mal

import "core:os"
import "core:mem/virtual"
import "core:fmt"

import "types"
import "reader"
import "core"
import "lib"

MalType :: types.MalType
Nil :: types.Nil
List :: types.List
Vector :: types.Vector
Symbol :: types.Symbol
Keyword :: types.Keyword
Hash_Map :: types.Hash_Map
Core_Fn :: types.Core_Fn
Fn :: types.Fn

Env :: types.Env

Reader_Error :: reader.Error

Eval_Error :: enum {
    none,
    not_a_symbol,
    not_a_function,
    lookup_failed,
    let_second_expr,
    fn_second_expr,
}

Error :: union {
    Reader_Error,
    Eval_Error,
}

READ :: proc(s: string) -> (MalType, reader.Error) {
    ast, err := reader.read_str(s)
    return ast, err
}

// Special forms and function application
EVAL :: proc(input: MalType, outer_env: ^Env) -> (res: MalType, err: Eval_Error) {
    // Declaring variables for use with TCO
    ast, env := input, outer_env
    // Main TCO loop. Any `continue` inside is a tailcall.
    for {
        if body, ok := ast.(List); ok {
            if len(body) == 0 do return body, .none

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
            case "eval":
                ast = EVAL(body[1], env) or_return
                continue
            }

            // Normal function evaluation
            evaled := eval_ast(body, env) or_return
            args := evaled.(List)[1:]
            // Needs to be passed as `&fn` to get
            // addressable semantics (as suggested by the compiler),
            // i.e. so that I can modify its contents.
            #partial switch &fn in evaled.(List)[0] {
                case Core_Fn:
                return apply_core_fn(fn, args)

                case Fn:
                ast, env = eval_closure(&fn, args)
                continue

                case:
                fmt.printfln("Error: '%s' is not a function.", body[0])
                return ast, .not_a_function
            }
        } else {
            // Not a function or special form
            return eval_ast(ast, env)
        }

    }
}

// Evaluation of symbols and data structures
eval_ast :: proc(input: MalType, outer_env: ^Env) -> (res: MalType, err: Eval_Error) {
    #partial switch ast in input {
    case List:
        list: [dynamic]MalType
        for elem in ast {
            evaled := EVAL(elem, outer_env) or_return
            append(&list, evaled)
        }
        return List(list[:]), .none

    case Vector:
        list: [dynamic]MalType
        for elem in ast {
            evaled := EVAL(elem, outer_env) or_return
            append(&list, evaled)
        }
        return Vector(list[:]), .none

    case Hash_Map:
        m := make(map[^MalType]MalType)
        for k, v in ast {
            evaled := EVAL(v, outer_env) or_return
            m[k] = evaled
        }
        return m, .none

    case Symbol:
        if val, ok := types.env_get(outer_env, ast); ok {
            return val, .none
        } else {
            fmt.printfln("Error: symbol '%s' not found", ast)
            return nil, .lookup_failed
        }
    }

    return input, .none
}

eval_def :: proc(ast: List, outer_env: ^Env) -> (res: MalType, err: Eval_Error) {
    sym := ast[1].(Symbol)
    // Evaluate the expression to get symbol value
    val := EVAL(ast[2], outer_env) or_return
    // Set environment variable
    types.env_set(outer_env, sym, val)
    // Retrieve variable
    s, ok := types.env_get(outer_env, sym)
    return s, .none
}

eval_let :: proc(ast: List, outer_env: ^Env) -> (body: MalType, env: ^Env, err: Eval_Error) {
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
    return ast[2], let_env, nil

    // Unpacking list or vector, error handling
    to_list :: proc(ast: MalType) -> (res: []MalType, err: Eval_Error) {
        binds, ok := lib.unpack_seq(ast)

        if !ok {
            fmt.println("Error: the second member of a let* expression must be a list or a vector.")
            return nil, .let_second_expr
        }

        if len(binds) % 2 != 0 {
            fmt.println("Error: the list of bindings in let* must have an even number of elements.")
            return nil, .let_second_expr
        }

        return binds, .none
    }
}

eval_if :: proc(ast: List, outer_env: ^Env) -> (res: MalType, err: Eval_Error) {
    cond := EVAL(ast[1], outer_env) or_return
    // If third element is missing, it defaults to nil
    third := ast[3] if len(ast) == 4 else MalType(Nil{})

    #partial switch t in cond {
    case Nil:
        return third, .none
    case bool:
        if !t {
            return third, .none
        }
    }
    return ast[2], .none
}

eval_do :: proc(ast: List, outer_env: ^Env) -> (res: MalType, err: Eval_Error) {
    for i in 1..<(len(ast) - 1) {
        res = EVAL(ast[i], outer_env) or_return
    }
    return ast[len(ast) - 1], .none
}

eval_fn :: proc(ast: List, outer_env: ^Env) -> (fn: Fn, err: Eval_Error) {
    // Capture parameters
    if params, ok := lib.unpack_seq(ast[1]); ok {
        for param in params do append(&fn.params, param.(Symbol))
    } else {
        fmt.println("Error: the second member of a fn* expression must be a vector or list.")
        return fn, .fn_second_expr
    }

    // Create function environment
    fn.env = new(Env)^
    fn.env.outer = outer_env

    fn.ast = &ast[2]
    return fn, .none
}

apply_core_fn :: proc(fn: Core_Fn, args: List) -> (res: MalType, err: Eval_Error) {
    // Extract arguments.
    // These have to be pointers (see types/types.odin)
    ptrs: [dynamic]^MalType
    defer delete(ptrs)
    for elem in args {
        p := new_clone(elem)
        append(&ptrs, p)
    }

    // Apply function and return the result.
    return fn(..ptrs[:]), .none
}

eval_closure :: proc(fn: ^Fn, args: List) -> (ast: MalType, env: ^Env) {
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
    // Define `not` using MAL
    rep("(def! not (fn* (a) (if a false true)))", &repl_env)

    return repl_env
}

PRINT :: proc(ast: MalType) -> string {
    return reader.pr_str(ast)
}

rep :: proc(s: string, env: ^Env) -> (p: string, err: Error) {
    r := READ(s) or_return
    e := EVAL(r, env) or_return
    p = PRINT(e)
    return p, err
}

main :: proc() {
    arena: virtual.Arena
    defer virtual.arena_destroy(&arena)
    context.allocator = virtual.arena_allocator(&arena)

    buf: [256]byte
    fmt.println("Welcome to MAL-Odin 0.0.6")
    main_env := create_env()

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

        if r, rep_err := rep(input, &main_env); rep_err != nil {
            switch rep_err {
            case Reader_Error.unbalanced_parentheses:
                fmt.println("Error: unbalanced parentheses.")
            case Reader_Error.unbalanced_quotes:
                fmt.println("Error: unbalanced quotes.")
            case Reader_Error.parse_int_error:
                fmt.println("Error: parse int error.")
            }
        } else {
            fmt.println(r)
        }
    }
}
