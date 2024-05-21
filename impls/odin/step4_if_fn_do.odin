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

        fst, ok := ast[0].(Symbol)
        // TODO: handle properly!!
        // if !ok do break

        // fmt.println("EVAL:", ast)
        // prn_env(outer_env)

        // Special forms:
        switch fst {
        case "def!":
            // res, err = eval_def(ast, outer_env)
                // cl, ok := res.(Closure)
                // fmt.println("env after def!:")
                // prn_env(&cl.env)
            // return res, err
            return eval_def(ast, outer_env)
        case "let*":
            return eval_let(ast, outer_env)
        case "do":
            return eval_do(ast, outer_env)
        case "if":
            return eval_if(ast, outer_env)
        case "fn*":
            fn, err := eval_fn(ast, outer_env)
            fmt.println("fn* env address:", &fn.env)
            prn_env(&fn.env)
            return fn, err
            // return eval_fn(ast, outer_env)
        }

        // Normal function evaluation
        evaled := eval_ast(ast, outer_env) or_return
        list := evaled.(List)
            // fmt.printfln("Evaled list:", list)
            // prn_env(outer_env)
        res, err = apply_fn(list)
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
                // cl, ok := val.(Closure)
                // if ok do prn_env(&cl.env)
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
    // capture args
    #partial switch args in ast[1] {
    case List:
        for arg in args {
            append(&fn.args, arg.(Symbol))
        }
    case:
        fmt.println("Error: the second member of a fn* expression must be a list.")
    }
    // Capture environment

    // First attempt, capturing vars out of environment and into map:
    // if outer_env != &main_env {
    //     for k, v in outer_env.data {
    //         fn.binds[k] = v
    //     }
    // }
    // It actually worked pretty well, except with nested envs
    // (e.g. let* inside a let*).
    //
    // Second attempt, making outer_env the function's env.
    // I don't think this is a good idea,
    // because it might lead to subtle bugs
    // (overwriting vars with the same name).
    // It worked in quite a few regular functions (non-closures),
    // but crashed on fibonacci and any closure.
    // fn.env = outer_env

    // Third attempt, what I believe should be the correct approach.
    // This does not work at all, and crashes with an address boundary error.
    // Somewhere, somehow, the memory gets overwritten, I guess?
    // new_env: Env
    // fn.env = &new_env
    // fn.env.outer = outer_env

    // So I tried printing out the value of the env.
    // It turned out that fn.env.outer has an address
    // inside eval_fn, but once it is returned to EVAL,
    // it disappears, along with anything inside fn.env.data
    //
    // user> (def! inc (fn* (x) (+ 1 x)))
    // env inside eval_fn: &Env{outer = 0x7B20AF68B900, data = map[test=8]}
    // env inside EVAL: &Env{outer = <nil>, data = map[]}
    //
    // Basically, fn.env becomes nil
    // new_env: Env
    // fn.env = &new_env
    // fn.env.outer = new_clone(outer_env^)

    // Ok, so maybe I should change the Closure type
    // to contain an actual Env, instead of a pointer to one?
    // [changed in types/types.odin]
    new_env: Env
    fn.env = new_env
    fn.env.outer = outer_env
    // I think I'm on the right track here.
    // The env correctly gets passed back to EVAL,
    // and shows up there.
    // The let* env gets destroyed right after evaluation,
    // but test data in the closure env survives.
    // Unfortunately, all closure tests still crash.
    // As far as I can tell, if the outer_env is not
    // main_env, but instead some other environment,
    // it becomes corrupted right after evaluation.
    // The env of a fn* closing over a fn* becomes nil,
    // while the env of a let* closing over a fn*
    // crashes with an address boundary error
    // (even when I just try to print the debug info).

    // This gets even weirder.
    // user> (def! gen-plus5 (fn* () (fn* (b) (+ 5 b))))
    // user> (def! plus5 (gen-plus5))
    // user> (plus5 3)
    // Error: symbol '+' not found
    // user> (let* (x 3) (plus5 x))
    // 8
    //
    // I think the issue here is that there are two
    // competing environments: one is the closure
    // and its outer envs, and the other one is where
    // it gets called from, and its outer envs.
    // This is basically lexical vs dynamic scoping.
    // These need to be reconsiled somehow.
    // UPDATE:
    // After reconsiling, plus5 crashes no matter
    // how I run it (when I try to print its outer env).
    // user> (def! gen-plus5 (fn* () (fn* (b) (+ 5 b))))
    // user> (def! plus5 (gen-plus5))
    // However, the env of gen-plus5 is alive and well.
    // So something happens to the pointer inside plus5.
    // It happens already in `def!`.

    fn.env.data["test"] = test_num
    test_num += 1
    // fmt.println("env inside eval_fn:")
    // prn_env(&fn.env)
    // capture body
    fn.body = &ast[2]
    return fn, .none
}

// DEBUG
test_num := 1
prn_env :: proc(env: ^Env) {
    if env == &main_env {
        fmt.println("main env")
        return
    }
    fmt.println("data:", env.data)
    if env.outer != nil {
        fmt.println("outer:")
        prn_env(env.outer)
    } else {
        fmt.println("nil")
    }
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
    fst := list[0]
    f, ok := fst.(Closure)
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
            // cl, ok := e.(Closure)
            // fmt.println("env after rep:")
            // prn_env(&cl.env)
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
        case ",env\n":
            fmt.println("data:", main_env.data)
            continue
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
