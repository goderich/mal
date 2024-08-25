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
    meta: ^MalType,
}
Vector :: struct {
    data: []MalType,
    meta: ^MalType,
}
// Odin does not allow MalType to be a key, but a pointer to it works.
Hash_Map :: struct {
    data: map[^MalType]MalType,
    meta: ^MalType,
}

Core_Fn :: struct {
    fn: proc(..MalType) -> (MalType, bool),
    meta: ^MalType,
}

Closure :: struct {
    params: [dynamic]Symbol,
    ast: ^MalType,
    env: Env,
    eval: proc(MalType, ^Env) -> (MalType, bool),
    is_macro: bool,
    meta: ^MalType,
}

Atom :: ^MalType

to_list :: proc{to_list_dynamic, to_list_static, to_list_vector}

to_list_dynamic :: proc(xs: [dynamic]MalType) -> List {
    defer delete(xs)
    list := new(List)
    data := make([]MalType, len(xs))
    copy(data, xs[:])
    list.data = data
    return list^
}

to_list_static :: proc(xs: []MalType) -> List {
    defer delete(xs)
    list := new(List)
    data := make([]MalType, len(xs))
    copy(data, xs)
    list.data = data
    return list^
}

to_list_vector :: proc(v: Vector) -> List {
    list := new(List)
    data := make([]MalType, len(v.data))
    copy(data, v.data)
    list.data = data
    return list^
}

to_vector :: proc{to_vector_dynamic, to_vector_static}

to_vector_dynamic :: proc(xs: [dynamic]MalType) -> Vector {
    defer delete(xs)
    vec := new(Vector)
    data := make([]MalType, len(xs))
    copy(data, xs[:])
    vec.data = data
    return vec^
}

to_vector_static :: proc(xs: []MalType) -> Vector {
    defer delete(xs)
    vec := new(Vector)
    data := make([]MalType, len(xs))
    copy(data, xs)
    vec.data = data
    return vec^
}
