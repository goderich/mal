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

            // Macro expansion:
            expanded, is_macro := macroexpand(body, env)
            if is_macro {
                if list, is_list := expanded.(List); is_list {
                    body = list
                } else {
                    return eval_ast(expanded, env)
                }
            }

            // Special forms:
            switch fst, ok := body[0].(Symbol); fst {
            case "def!":
                return eval_def(body, env)
            case "defmacro!":
                return eval_defmacro(body, env)
            case "let*":
                ast, env, ok = eval_let(body, env)
                if !ok do return ast, false
                continue
            case "do":
                ast, ok = eval_do(body, env)
                if !ok do return ast, false
                continue
            case "if":
                ast, ok = eval_if(body, env)
                if !ok do return ast, false
                continue
            case "fn*":
                return eval_closure(body, env)
            case "eval":
                ast, ok = EVAL(body[1], env)
                if !ok do return ast, false
                env = outer_env
                continue
            case "quote":
                return body[1], true
            case "quasiquoteexpand":
                return eval_quasiquote(body[1]), true
            case "quasiquote":
                ast = eval_quasiquote(body[1])
                continue
            case "macroexpand":
                ast, ok = macroexpand(body[1], env)
                if !ok do return string("Not a macro form."), false
                return ast, true
            case "try*":
                return try_catch(body, env)
            }

            // Normal function evaluation
            evaled, ok_evaled := eval_ast(body, env)
            if !ok_evaled do return evaled, false
            args := evaled.(List)[1:]
            // Needs to be passed as `&fn` to get
            // addressable semantics (as suggested by the compiler),
            // i.e. so that I can modify its contents.
            #partial switch &fn in evaled.(List)[0] {
                case Core_Fn:
                return fn(..cast([]MalType)args)

                case Closure:
                types.eval_closure(&fn, args)
                ast, env = fn.ast^, &fn.env
                continue

                case:
                err := fmt.aprintf("'%s' not found", body[0])
                return err, false
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
            evaled, ok_evaled := EVAL(elem, outer_env)
            if !ok_evaled do return evaled, false
            append(&list, evaled)
        }
        return List(list[:]), true

    case Vector:
        list: [dynamic]MalType
        for elem in ast {
            evaled, ok_evaled := EVAL(elem, outer_env)
            if !ok_evaled do return evaled, false
            append(&list, evaled)
        }
        return Vector(list[:]), true

    case Hash_Map:
        m := make(map[^MalType]MalType)
        for k, v in ast {
            evaled, ok_evaled := EVAL(v, outer_env)
            if !ok_evaled do return v, false
            m[k] = evaled
        }
        return m, true

    case Symbol:
        if val, ok := types.env_get(outer_env, ast); ok {
            return val, true
        } else {
            err := fmt.aprintf("'%s' not found", ast)
            return err, false
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

// Very similar to `eval_def` except for the is_macro flag
eval_defmacro :: proc(ast: List, outer_env: ^Env) -> (res: MalType, ok: bool) {
    sym := ast[1].(Symbol) or_return
    fn := eval_closure(ast[2].(List), outer_env) or_return
    fn.is_macro = true
    types.env_set(outer_env, sym, fn)
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
        binds, ok_binds := lib.unpack_seq(ast)

        if !ok_binds {
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
    cond, ok_cond := EVAL(ast[1], outer_env)
    if !ok_cond do return cond, false
    // If third element is missing, it defaults to nil
    third := ast[3] if len(ast) == 4 else nil

    is_true, is_bool := cond.(bool)
    if (is_bool && !is_true) || cond == nil {
        return third, true
    }
    return ast[2], true
}

eval_do :: proc(ast: List, outer_env: ^Env) -> (res: MalType, ok: bool) {
    for i in 1..<len(ast) {
        res = EVAL(ast[i], outer_env) or_return
    }
    return res, true
}

eval_closure :: proc(ast: List, outer_env: ^Env) -> (fn: Closure, ok: bool) {
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
    fn.eval = EVAL

    fn.ast = &ast[2]
    return fn, true
}

eval_quasiquote :: proc(ast: MalType) -> MalType {
    #partial switch t in ast {
    case Symbol:
        arr := lib.concat(Symbol("quote"), t)
        return List(arr[:])
    case Hash_Map:
        arr := lib.concat(Symbol("quote"), t)
        return List(arr[:])
    case List:
        return eval_quasiquote_list(t)
    case Vector:
        list: [dynamic]MalType
        append(&list,
               Symbol("vec"),
               eval_quasiquote_list(cast(List)t[:], true))
        return List(list[:])
    }
    return ast

    eval_quasiquote_list :: proc(ast: List, is_vec := false) -> MalType {
        // Empty
        if len(ast) == 0 do return ast

        // Unquote
        if sym, ok := ast[0].(Symbol); ok && !is_vec && sym == Symbol("unquote") {
            return ast[1]
        }

        // Not unquote
        acc: [dynamic]MalType
        #reverse for el in ast {
            // Splice unquote
            if list, is_list := el.(List); is_list && len(list) > 1 {
                sym_el, ok_el := list[0].(Symbol)
                if ok_el && sym_el == Symbol("splice-unquote") {
                    acc = lib.concat(Symbol("concat"), list[1], List(acc[:]))
                    continue
                }
            }

            // Not splice unquote
            acc = lib.concat(Symbol("cons"), eval_quasiquote(el), List(acc[:]))
        }
        return List(acc[:])
    }
}

macroexpand :: proc(ast: MalType, env: ^Env) -> (res: MalType, ok: bool) {
    // Shadow fn parameter to allow mutation
    ast := ast

    // Expand as long as the first element is a macro
    fn, is_macro := get_macro_fn(ast, env)
    if !is_macro do return ast, false
    for is_macro {
        args := cast([]MalType)ast.(List)[1:]
        ast = types.apply(fn, ..args) or_return
        fn, is_macro = get_macro_fn(ast, env)
    }

    return ast, true

    get_macro_fn :: proc(ast: MalType, env: ^Env) -> (fn: Closure, is_macro: bool) {
        list := ast.(List) or_return
        sym := list[0].(Symbol) or_return
        val := types.env_get(env, sym) or_return
        fn = val.(Closure) or_return
        return fn, fn.is_macro
    }
}

try_catch :: proc(ast: List, env: ^Env) -> (res: MalType, ok: bool) {
    // Syntax is as follows:
    // (try* A (catch* B C))
    res_A, ok_A := EVAL(ast[1], env)
    if ok_A do return res_A, true

    // If A throws an exception:
    catch_block := ast[2].(List) or_return
    // Bind exception in A to symbol B
    sym := catch_block[1].(Symbol) or_return
    types.env_set(env, sym, res_A)
    // Then evaluate C
    return EVAL(catch_block[2], env)
}

create_env :: proc() -> ^Env {
    repl_env := new(Env)
    // Load core lib
    for name, fn in core.make_ns() {
        types.env_set(repl_env, name, Core_Fn(fn))
    }
    // Define some basic functions using MAL
    rep("(def! not (fn* (a) (if a false true)))", repl_env)
    rep(`(def! load-file (fn* (f) (eval (read-string (str "(do " (slurp f) "\nnil)")))))`, repl_env)
    rep(`(defmacro! cond (fn* (& xs) (if (> (count xs) 0) (list 'if (first xs) (if (> (count xs) 1) (nth xs 1) (throw "odd number of forms to cond")) (cons 'cond (rest (rest xs)))))))`, repl_env)
    return repl_env
}

PRINT :: proc(ast: MalType) -> string {
    return reader.pr_str(ast)
}

rep :: proc(s: string, env: ^Env) -> (p: string, ok: bool) {
    r := READ(s) or_return
    e, ok_eval := EVAL(r, env)
    p = PRINT(e)
    return p, ok_eval
}

main :: proc() {
    arena: virtual.Arena
    defer virtual.arena_destroy(&arena)
    context.allocator = virtual.arena_allocator(&arena)

    main_env := create_env()
    // Read command line arguments:
    set_argv(main_env)

    // Running a script from a file:
    if len(os.args) > 1 {
        cmd := fmt.aprintf(`(load-file "{:s}")`, os.args[1])
        rep(cmd, main_env)
        return
    }

    // Running interactively:
    buf: [256]byte
    fmt.println("Welcome to MAL-Odin 0.0.9")
    for {
        // Prompt
        fmt.print("user> ")
        n, err := os.read(os.stdin, buf[:])
        if err < 0 {
            fmt.println("Error: read error.")
            continue
        }

        // Special cases
        input := string(buf[:n])
        switch input {
        case ",q\n", ",quit\n":
            return
        case "\n":
            continue
        }

        // Normal handling
        if r, ok := rep(input, main_env); ok {
            fmt.println(r)
        } else {
            fmt.println("Exception:", r)
        }
    }

    set_argv :: proc(env: ^Env) {
        args: [dynamic]MalType
        for i in 2..<len(os.args) {
            append(&args, os.args[i])
        }
        types.env_set(env, "*ARGV*", List(args[:]))
    }
}
