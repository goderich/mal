package env

import "../reader"
import "../types"

MalType :: types.MalType
List :: types.List
Vector :: types.Vector
Symbol :: types.Symbol
Keyword :: types.Keyword
Hash_Map :: types.Hash_Map

Env :: struct {
    outer: ^Env,
    data: map[Symbol]MalType,
}

env_set :: proc(env: ^Env, key: Symbol, val: MalType) {
    env.data[key] = val
}

env_find :: proc(env: ^Env, key: Symbol) -> (val: MalType, found: bool) {
    res, ok := env.data[key]
    switch {
    case !ok && env.outer == nil:
        val, found = nil, false
    case !ok:
        val, found = env_find(env.outer, key)
    case ok:
        val, found = res, true
    }
    return
}

env_get :: proc(env: ^Env, key: Symbol) -> (val: MalType, ok: bool) {
    return env_find(env, key)
}
