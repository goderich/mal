#[derive(Debug, PartialEq, Eq)]
pub enum MalType {
    Nil,
    Bool(bool),
    Int(i64),
    Str(String),
    Symbol(String),
    Keyword(String),
    List(Vec<MalType>),
    Vector(Vec<MalType>),
}
