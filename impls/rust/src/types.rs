#[derive(Debug, PartialEq, Eq)]
pub enum MalType {
    Int(i64),
    Symbol(String),
    List(Vec<MalType>),
}
