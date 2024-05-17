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
}

Symbol :: distinct string
Keyword :: distinct string
Nil :: struct {}

List :: distinct []MalType
Vector :: distinct []MalType
// Odin does not allow MalType to be a key, but a pointer to it works.
Hash_Map :: map[^MalType]MalType
