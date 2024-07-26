use itertools::{intersperse, Itertools};

use crate::types::MalType;
use crate::types::MalType::{Int, List, Symbol};

pub fn pr_str(input: &MalType) -> String {
    match input {
        Int(n) => n.to_string(),
        Symbol(s) => s.clone(),
        List(list) => pr_list(list),
    }
}

#[allow(unstable_name_collisions)]
fn pr_list(list: &Vec<MalType>) -> String {
    let mut str = String::new();
    str.push('(');
    list.iter()
        .map(|x| pr_str(x))
        .intersperse(" ".to_string())
        .for_each(|s: String| str.push_str(&s));
    str.push(')');
    str
}
