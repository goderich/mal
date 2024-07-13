package types

// Because Odin does not have closures,
// function application for MAL is somewhat difficult.
// Here is a workaround for having functions in `core`
// be able to use function application themselves.
// This workaround was taken from similar solutions
// in the Zig and Rust implementations of MAL.

apply :: proc(farg: MalType, args: ..MalType) -> (res: MalType, ok: bool) {
    #partial switch &fn in farg {
    case Core_Fn:
        return fn(..args)
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
