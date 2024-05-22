package mal

import "core:os"
import "core:mem/virtual"
import "core:fmt"
import "core:strings"

import "types"
import "reader"
import "core"

MalType :: types.MalType
Nil :: types.Nil
List :: types.List
Vector :: types.Vector
Symbol :: types.Symbol
Keyword :: types.Keyword
Hash_Map :: types.Hash_Map
Fn :: types.Fn
Closure :: types.Closure

Env :: types.Env

Reader_Error :: reader.Error

Eval_Error :: enum {
    none,
    not_a_symbol,
    not_a_function,
    lookup_failed,
    let_second_expr,
}

Error :: union {
    Reader_Error,
    Eval_Error,
}

// Global environment created here for now.
main_env := create_env()

READ :: proc(s: string) -> (MalType, reader.Error) {
    ast, err := reader.read_str(s)
    return ast, err
}

// Special forms and function application
EVAL :: proc(input: MalType, outer_env: ^Env) -> (res: MalType, err: Eval_Error) {
    #partial switch ast in input {
    case List:
        if len(ast) == 0 do return ast, .none

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
            return eval_fn(ast, outer_env)
        }

        // Normal function evaluation
        evaled := eval_ast(ast, outer_env) or_return
        res, err = apply_fn(evaled.(List))
        if err == .not_a_function {
            fmt.printfln("Error: '%s' is not a function.", ast[0])
        }
        return res, err
    }

    return eval_ast(input, outer_env)
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
        val, ok := types.env_get(outer_env, ast)
        if ok {
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

eval_let :: proc(ast: List, outer_env: ^Env) -> (res: MalType, err: Eval_Error) {
    let_env: Env
    let_env.outer = outer_env

    bindings: []MalType
    #partial switch t in ast[1] {
    case List:
        bindings = cast([]MalType)t
    case Vector:
        bindings = cast([]MalType)t
    case:
        fmt.println("Error: the second member of a let* expression must be a list or a vector.")
        return nil, .let_second_expr
    }

    if len(bindings) % 2 != 0 {
        fmt.println("Error: the list of bindings in let* must have an even number of elements.")
        return nil, .let_second_expr
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

eval_if :: proc(ast: List, outer_env: ^Env) -> (res: MalType, err: Eval_Error) {
    cond := EVAL(ast[1], outer_env) or_return
    // If third element is missing, it defaults to nil
    third:= ast[3] if len(ast) == 4 else MalType(Nil{})

    #partial switch t in cond {
    case Nil:
        return EVAL(third, outer_env)
    case bool:
        if !t {
            return EVAL(third, outer_env)
        }
    }
    return EVAL(ast[2], outer_env)
}

eval_do :: proc(ast: List, outer_env: ^Env) -> (res: MalType, err: Eval_Error) {
    for i in 1..<len(ast) {
        res = EVAL(ast[i], outer_env) or_return
    }
    return res, .none
}

eval_fn :: proc(ast: List, outer_env: ^Env) -> (fn: Closure, err: Eval_Error) {
    // Capture args
    #partial switch args in ast[1] {
    case List:
        for arg in args {
            append(&fn.args, arg.(Symbol))
        }
    case:
        fmt.println("Error: the second member of a fn* expression must be a list.")
    }

    // Create function environment
    new_env: Env
    fn.env = new_env
    fn.env.outer = outer_env

    fn.body = &ast[2]
    return fn, .none
}

apply_fn :: proc(list: List) -> (res: MalType, err: Eval_Error) {
    // Extract function
    fst := list[0]
    f, ok := fst.(Fn)
    if !ok do return apply_closure(list)

    // Extract arguments.
    // These have to be pointers (see types/types.odin)
    ptrs: [dynamic]^MalType
    defer delete(ptrs)
    for elem in list[1:] {
        p := new_clone(elem)
        append(&ptrs, p)
    }

    // Apply function and return the result.
    return f(..ptrs[:]), .none
}

apply_closure :: proc(list: List) -> (res: MalType, err: Eval_Error) {
    // Get the address of the first element,
    // which should be a closure.
    f, ok := &list[0].(Closure)
    if !ok do return nil, .not_a_function

    for i in 0..<len(f.args) {
        // "Rest" args with '&'
        if f.args[i] == "&" {
            rest_args := f.args[i+1]
            rest_vals := List(list[i+1:])
            types.env_set(&f.env, rest_args, rest_vals)
            break
        }
        // Regular args
        types.env_set(&f.env, f.args[i], list[i+1])
    }

    return EVAL(f.body^, &f.env)
}

create_env :: proc() -> (repl_env: Env) {
    for name, fn in core.make_ns() {
        types.env_set(&repl_env, name, Fn(fn))
    }

    return repl_env
}

PRINT :: proc(ast: MalType) -> string {
    return reader.pr_str(ast)
}

rep :: proc(s: string) -> (p: string, err: Error) {
    r := READ(s) or_return
    e := EVAL(r, &main_env) or_return
    p = PRINT(e)
    return p, err
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

        r, rep_err := rep(input)
        if rep_err != nil {
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
