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
    Closure,

    Atom,
}

Symbol :: distinct string
Keyword :: distinct string
Nil :: struct {}

List :: distinct []MalType
Vector :: distinct []MalType
// Odin does not allow MalType to be a key, but a pointer to it works.
Hash_Map :: map[^MalType]MalType

Core_Fn :: proc(..MalType) -> MalType

Closure :: struct {
    params: [dynamic]Symbol,
    ast: ^MalType,
    env: Env,
    eval: proc(MalType, ^Env) -> (MalType, bool),
}

Atom :: ^MalType

apply :: proc(farg: MalType, args: ..MalType) -> (res: MalType, ok: bool) {
    #partial switch &fn in farg {
    case Core_Fn:
        return fn(..args), true
    case Closure:
        eval_closure(&fn, List(args))
        return fn.eval(fn.ast^, &fn.env)
    }
    return nil, false
}

// Maps fn parameters to args and adds them to
// the closure environment, so no return needed.
eval_closure :: proc(fn: ^Closure, args: List) {
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
