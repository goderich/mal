package types

MalType :: union {
    int,
    string,
    bool,
    Nil,
    Symbol,
    Keyword,

    List,
    Vector,
    Hash_Map,

    Core_Fn,
    Fn,

    Atom,
}

Symbol :: distinct string
Keyword :: distinct string
Nil :: struct {}

List :: distinct []MalType
Vector :: distinct []MalType
// Odin does not allow MalType to be a key, but a pointer to it works.
Hash_Map :: map[^MalType]MalType

// A similar thing happens with functions,
// but I'm not sure why a pointer is needed here.
Core_Fn :: proc(..^MalType) -> MalType

Fn :: struct {
    params: [dynamic]Symbol,
    ast: ^MalType,
    env: Env,
    eval: proc(^MalType, ^Env) -> (MalType, bool),
}

Atom :: ^MalType

apply :: proc(farg: MalType, args: ..MalType) -> (res: MalType, ok: bool) {
    #partial switch &fn in farg {
    case Core_Fn:
        return apply_core_fn(fn, List(args))
    case Fn:
        eval_closure(&fn, List(args))
        return fn.eval(fn.ast, &fn.env)
    }
    return nil, false
}

apply_ptrs :: proc(farg: ^MalType, arg_ptrs: ..^MalType) -> (res: MalType, ok: bool) {
    #partial switch &fn in farg^ {
    case Core_Fn:
        return fn(..arg_ptrs), true
    case Fn:
        args: [dynamic]MalType
        for ptr in arg_ptrs do append(&args, ptr^)
        eval_closure(&fn, List(args[:]))
        return fn.eval(fn.ast, &fn.env)
    }
    return nil, false
}

apply_core_fn :: proc(fn: Core_Fn, args: List) -> (res: MalType, ok: bool) {
    // Extract arguments (these have to be pointers).
    ptrs: [dynamic]^MalType
    defer delete(ptrs)
    for &elem in args {
        append(&ptrs, &elem)
    }

    // Apply function and return the result.
    return fn(..ptrs[:]), true
}

// Maps fn parameters to args and adds them to
// the closure environment, so no return needed.
eval_closure :: proc(fn: ^Fn, args: List) {
    for i in 0..<len(fn.params) {
        // "Rest" params with '&'
        if fn.params[i] == "&" {
            rest_params := fn.params[i+1]
            rest_vals := args[i:]
            env_set(&fn.env, rest_params, rest_vals)
            break
        }
        // Regular args
        env_set(&fn.env, fn.params[i], args[i])
    }
}
