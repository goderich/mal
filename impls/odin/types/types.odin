package types

MalType :: union {
    // nil is implied in Odin

    int,
    string,
    bool,
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

List :: struct {
    data: []MalType,
    meta: map[^MalType]MalType,
}
Vector :: struct {
    data: []MalType,
    meta: map[^MalType]MalType,
}
// Odin does not allow MalType to be a key, but a pointer to it works.
Hash_Map :: struct {
    data: map[^MalType]MalType,
    meta: map[^MalType]MalType,
}

Core_Fn :: struct {
    fn: proc(..MalType) -> (MalType, bool),
    meta: map[^MalType]MalType,
}

Closure :: struct {
    params: [dynamic]Symbol,
    ast: ^MalType,
    env: Env,
    eval: proc(MalType, ^Env) -> (MalType, bool),
    is_macro: bool,
    meta: map[^MalType]MalType,
}

Atom :: ^MalType

to_list :: proc{to_list_dynamic, to_list_static, to_list_vector}

to_list_dynamic :: proc(xs: [dynamic]MalType) -> List {
    defer delete(xs)
    list := new(List)
    list.data = xs[:]
    return list^
}

to_list_static :: proc(xs: []MalType) -> List {
    defer delete(xs)
    list := new(List)
    list.data = xs
    return list^
}

to_list_vector :: proc(v: Vector) -> List {
    list := new(List)
    list.data = v.data
    return list^
}

to_vector :: proc{to_vector_dynamic, to_vector_static}

to_vector_dynamic :: proc(xs: [dynamic]MalType) -> Vector {
    defer delete(xs)
    vec := new(Vector)
    vec.data = xs[:]
    return vec^
}

to_vector_static :: proc(xs: []MalType) -> Vector {
    defer delete(xs)
    vec := new(Vector)
    vec.data = xs
    return vec^
}
