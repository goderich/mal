package mal

import "core:os"
import "core:mem/virtual"
import "core:fmt"
import "core:strings"

import "types"
import "reader"
import "env"
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

Env :: env.Env

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
EVAL :: proc(input: MalType, repl_env: ^Env) -> (res: MalType, err: Eval_Error) {
    #partial switch ast in input {
    case List:
        if len(ast) == 0 do return ast, .none

        fst, ok := ast[0].(Symbol)
        // TODO: handle properly!!
        // if !ok do break

        // Special forms:
        switch fst {
        case "def!":
            return eval_def(ast, repl_env)
        case "let*":
            return eval_let(ast, repl_env)
        case "do":
            return eval_do(ast, repl_env)
        case "if":
            return eval_if(ast, repl_env)
        case "fn*":
            fn, err := eval_fn(ast, repl_env)
            return fn, err
        }

        // Normal function evaluation
        evaled := eval_ast(ast, repl_env) or_return
        list := evaled.(List)
        res, err = apply_fn(list, repl_env)
        if err == .not_a_function {
            fmt.printfln("Error: '%s' is not a function.", ast[0])
        }
        return res, err
    }

    return eval_ast(input, repl_env)
}

// Evaluation of symbols and data structures
eval_ast :: proc(input: MalType, repl_env: ^Env) -> (res: MalType, err: Eval_Error) {
    #partial switch ast in input {
    case List:
        list: [dynamic]MalType
        for elem in ast {
            evaled := EVAL(elem, repl_env) or_return
            append(&list, evaled)
        }
        return List(list[:]), .none

    case Vector:
        list: [dynamic]MalType
        for elem in ast {
            evaled := EVAL(elem, repl_env) or_return
            append(&list, evaled)
        }
        return Vector(list[:]), .none

    case Hash_Map:
        m := make(map[^MalType]MalType)
        for k, v in ast {
            evaled := EVAL(v, repl_env) or_return
            m[k] = evaled
        }
        return m, .none

    case Symbol:
        val, ok := env.env_get(repl_env, ast)
        if ok {
            return val, .none
        } else {
            fmt.printfln("Error: symbol '%s' not found", ast)
            return nil, .lookup_failed
        }
    }

    return input, .none
}

eval_def :: proc(ast: List, repl_env: ^Env) -> (res: MalType, err: Eval_Error) {
    sym := ast[1].(Symbol)
    // Make a permanent copy of the symbol (see clone_symbol)
    sym = clone_symbol(sym)
    // Evaluate the expression to get symbol value
    val := EVAL(ast[2], repl_env) or_return
    // Set environment variable
    env.env_set(repl_env, sym, val)
    // Retrieve variable
    s, ok := env.env_get(repl_env, sym)
    return s, .none
}

// Create a new Symbol in memory and copy contents to it.
// Provides protection from overwriting.
// This is important because variable names defined in the REPL
// are not independent strings/Symbols, but instead
// slices of the input string (in other words, a pointer and a length),
// which get overwritten if a new input is long enough.
// Pointers, mang.
clone_symbol :: proc(s: Symbol) -> Symbol {
    return Symbol(strings.clone(string(s)))
}

eval_let :: proc(ast: List, repl_env: ^Env) -> (res: MalType, err: Eval_Error) {
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
        env.env_set(&let_env, name, val)
    }
    // Evaluate final expression
    return EVAL(ast[2], &let_env)
}

eval_if :: proc(ast: List, repl_env: ^Env) -> (res: MalType, err: Eval_Error) {
    cond := EVAL(ast[1], repl_env) or_return
    // If third element is missing, it defaults to nil
    third:= ast[3] if len(ast) == 4 else MalType(Nil{})

    #partial switch t in cond {
    case Nil:
        return EVAL(third, repl_env)
    case bool:
        if !t {
            return EVAL(third, repl_env)
        }
    }
    return EVAL(ast[2], repl_env)
}

eval_do :: proc(ast: List, repl_env: ^Env) -> (res: MalType, err: Eval_Error) {
    for i in 1..<len(ast) {
        res = EVAL(ast[i], repl_env) or_return
    }
    return res, .none
}

eval_fn :: proc(ast: List, repl_env: ^Env) -> (fn: Closure, err: Eval_Error) {
    // capture args
    #partial switch args in ast[1] {
    case List:
        for arg in args {
            append(&fn.binds, arg.(Symbol))
        }
    case:
        fmt.println("Error: the second member of a fn* expression must be a list.")
    }
    // capture body
    fn.body = &ast[2]
    return fn, .none
}

apply_fn :: proc(ast: List, repl_env: ^Env) -> (res: MalType, err: Eval_Error) {
    list := cast([]MalType)ast

    // Extract function
    fst := list[0]
    f, ok := fst.(Fn)
    if !ok do return apply_closure(ast, repl_env)

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

apply_closure :: proc(ast: List, repl_env: ^Env) -> (res: MalType, err: Eval_Error) {
    list := cast([]MalType)ast
    fst := list[0]
    f, ok := fst.(Closure)
    if !ok do return nil, .not_a_function

    fn_env: Env
    fn_env.outer = repl_env

    for i in 0..<len(f.binds) {
        env.env_set(&fn_env, f.binds[i], list[i+1])
    }

    return EVAL(f.body^, &fn_env)
}

create_env :: proc() -> (repl_env: Env) {
    using env

    for name, fn in core.make_ns() {
        env_set(&repl_env, name, Fn(fn))
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
