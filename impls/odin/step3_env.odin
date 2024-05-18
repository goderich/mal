package mal

import "core:os"
import "core:mem/virtual"
import "core:fmt"
import "core:strings"

import "types"
import "reader"
import "env"

MalType :: types.MalType
List :: types.List
Vector :: types.Vector
Symbol :: types.Symbol
Keyword :: types.Keyword
Hash_Map :: types.Hash_Map
Fn :: types.Fn

Env :: env.Env

Reader_Error :: reader.Error

Eval_Error :: enum {
    none,
    not_a_symbol,
    not_a_function,
    lookup_failed,
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
EVAL :: proc(input: MalType, repl_env: ^Env) -> (res: MalType, err: Eval_Error) {
    #partial switch ast in input {
    case List:
        if len(ast) == 0 do return ast, .none
        // Special forms:
        switch ast[0].(Symbol) {
        case "def!":
            sym := ast[1].(Symbol)
            // Make a permanent copy of the symbol
            sym = clone_symbol(sym)
            // Evaluate the expression to get symbol value
            val := EVAL(ast[2], repl_env) or_return
            // Set environment variable
            env.env_set(repl_env, sym, val)
            // Retrieve variable
            s, ok := env.env_get(repl_env, sym)
            return s, .none

        case "let*":
            // create let_env
            let_env: Env
            let_env.outer = repl_env
            // TODO: check ast[1] is List or Vector
            // TODO: check number of items is even
            bindings := ast[1].(List)
            // iterate over pairs, adding bindings
            for i := 0; i < len(bindings); i += 2 {
                name := bindings[i].(Symbol)
                val := EVAL(bindings[i+1], &let_env) or_return
                env.env_set(&let_env, name, val)
            }
            // eval final exp
            return EVAL(ast[2], &let_env)
        }
        // Normal List evaluation
        evaled := eval_ast(ast, repl_env) or_return
        list := evaled.(List)
        return apply_fn(list, repl_env)
    }

    // DEBUGGING ENV
    sym, ok := input.(Symbol)
    if ok && string(sym) == "env" {
        fmt.println("Current environment:")
        fmt.println("-------------------")
        fmt.println("Outer:", repl_env.outer)
        fmt.println("Data:")
        i := 1
        for k, v in repl_env.data {
            fmt.println("Item number", i)
            fmt.println("key:", k)
            fmt.println("value:", v)
            i += 1
        }
        return nil, .none
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
            return nil, .lookup_failed
        }
    }

    return input, .none
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

apply_fn :: proc(ast: List, repl_env: ^Env) -> (res: MalType, err: Eval_Error) {
    list := cast([]MalType)ast

    // Extract function
    fst := list[0]
    f, ok := fst.(Fn)
    if !ok do return nil, .not_a_function

    // Extract arguments.
    // These have to be pointers (see types/types.odin)
    ptrs: [dynamic]^MalType
    for elem in list[1:] {
        p := new_clone(elem)
        append(&ptrs, p)
    }

    // Apply function and return the result.
    return f(..ptrs[:]), err
}

create_env :: proc() -> (repl_env: Env) {
    using env

    add := proc(xs: ..^MalType) -> MalType {
        acc := 0
        for x in xs {
            n := x^.(int)
            acc += n
        }
        return acc
    }
    env_set(&repl_env, "+", Fn(add))

    multiply := proc(xs: ..^MalType) -> MalType {
        acc := 1
        for x in xs {
            n := x^.(int)
            acc *= n
        }
        return acc
    }
    env_set(&repl_env, "*", Fn(multiply))

    subtract := proc(xs: ..^MalType) -> MalType {
        acc := xs[0].(int)
        rest := xs[1:]
        for x in rest {
            n := x^.(int)
            acc -= n
        }
        return acc
    }
    env_set(&repl_env, "-", Fn(subtract))

    divide := proc(xs: ..^MalType) -> MalType {
        acc := xs[0].(int)
        rest := xs[1:]
        for x in rest {
            n := x^.(int)
            acc /= n
        }
        return acc
    }
    env_set(&repl_env, "/", Fn(divide))

    return repl_env
}

PRINT :: proc(ast: MalType) -> string {
    return reader.pr_str(ast)
}

main_env := create_env()
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
