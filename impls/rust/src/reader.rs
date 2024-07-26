use nom::branch::alt;
use nom::bytes::complete::take_while1;
use nom::character::complete::i64;
use nom::character::complete::{char, one_of};
use nom::combinator::{map_res, value};
use nom::multi::{many0, many1, separated_list0};
use nom::sequence::delimited;
use nom::IResult;

use crate::types::MalType;

pub struct ReaderError {
    message: String,
}

pub fn read_str(s: String) -> Result<MalType, ReaderError> {
    match form_parser(s.trim()) {
        Ok((_, output)) => Ok(output),
        Err(_) => Err(ReaderError {
            message: String::from("Reader Error!"),
        }),
    }
}

fn form_parser(input: &str) -> IResult<&str, MalType> {
    alt((list_parser, atom_parser))(input)
}

fn atom_parser(input: &str) -> IResult<&str, MalType> {
    alt((int_parser, symbol_parser))(input)
}

fn symbol_parser(input: &str) -> IResult<&str, MalType> {
    let (rest, output) = symbol_name_parser(input)?;
    Ok((rest, MalType::Symbol(output.to_string())))
}

fn symbol_name_parser(input: &str) -> IResult<&str, &str> {
    take_while1(|c: char| {
        !(c.is_whitespace()
            || c == ','
            || c == '('
            || c == ')'
            || c == '['
            || c == ']'
            || c == '{'
            || c == '}')
    })(input)
}

fn int_parser(input: &str) -> IResult<&str, MalType> {
    let (rest, num) = i64(input)?;
    Ok((rest, MalType::Int(num)))
}

fn list_parser(input: &str) -> IResult<&str, MalType> {
    let (rest, list) = delimited(
        char('('),
        delimited(
            many0(whitespace),
            separated_list0(many1(whitespace), form_parser),
            many0(whitespace),
        ),
        char(')'),
    )(input)?;
    Ok((rest, MalType::List(list)))
}

fn whitespace(input: &str) -> IResult<&str, ()> {
    value((), one_of(" \t\n\r,"))(input)
}

#[cfg(test)]
mod reader_tests {
    use super::*;

    #[test]
    fn symbol() {
        match symbol_parser("symbol1, symbol2") {
            Ok((rest, output)) => {
                assert_eq!(rest, ", symbol2");
                assert_eq!(output, MalType::Symbol("symbol1".to_string()));
            }
            Err(_) => panic!("Test error."),
        }
    }

    #[test]
    fn integers() {
        match int_parser("123 456") {
            Ok((rest, output)) => {
                assert_eq!(rest, " 456");
                assert_eq!(output, MalType::Int(123));
            }
            Err(_) => panic!("Test error."),
        }
    }

    #[test]
    fn negative_integers() {
        match int_parser("-123 456") {
            Ok((rest, output)) => {
                assert_eq!(rest, " 456");
                assert_eq!(output, MalType::Int(-123));
            }
            Err(_) => panic!("Test error."),
        }
    }

    #[test]
    fn list() {
        match list_parser("(+ 123 456 789)") {
            Ok((rest, output)) => {
                assert_eq!(rest, "");
                assert_eq!(
                    output,
                    MalType::List(vec![
                        MalType::Symbol(String::from("+")),
                        MalType::Int(123),
                        MalType::Int(456),
                        MalType::Int(789)
                    ])
                );
            }
            Err(_) => panic!("Test error."),
        }
    }

    #[test]
    fn comma_sep_list() {
        match list_parser("(123,456,789)") {
            Ok((rest, output)) => {
                assert_eq!(rest, "");
                assert_eq!(
                    output,
                    MalType::List(vec![
                        MalType::Int(123),
                        MalType::Int(456),
                        MalType::Int(789)
                    ])
                );
            }
            Err(_) => panic!("Test error."),
        }
    }

    #[test]
    fn list_whitespace() {
        match list_parser("(  123     456   789  )  ") {
            Ok((_, output)) => {
                assert_eq!(
                    output,
                    MalType::List(vec![
                        MalType::Int(123),
                        MalType::Int(456),
                        MalType::Int(789)
                    ])
                );
            }
            Err(_) => panic!("Test error."),
        }
    }

    #[test]
    fn nested_lists() {
        match list_parser("(+ 123 (- 456 789))") {
            Ok((_, output)) => {
                assert_eq!(
                    output,
                    MalType::List(vec![
                        MalType::Symbol(String::from("+")),
                        MalType::Int(123),
                        MalType::List(vec![
                            MalType::Symbol(String::from("-")),
                            MalType::Int(456),
                            MalType::Int(789)
                        ])
                    ])
                );
            }
            Err(_) => panic!("Test error."),
        }
    }
}
