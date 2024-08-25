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

to_list :: proc{to_list_static, to_list_vector}

to_list_static :: proc(xs: []MalType) -> List {
    list := new(List)
    list.data = make([]MalType, len(xs))
    copy(list.data, xs)
    return list^
}

to_list_vector :: proc(v: Vector) -> List {
    list := new(List)
    list.data = make([]MalType, len(v.data))
    copy(list.data, v.data)
    return list^
}

to_vector :: proc(xs: []MalType) -> Vector {
    vec := new(Vector)
    vec.data = make([]MalType, len(xs))
    copy(vec.data, xs)
    return vec^
}
