use std::io;
use std::io::Write;

use printer::pr_str;
use reader::ReaderError;
use types::MalType;

mod printer;
mod reader;
mod types;

fn read(s: String) -> Result<MalType, ReaderError> {
    reader::read_str(s)
}

fn eval(input: MalType) -> MalType {
    input
}

fn print(input: MalType) -> String {
    pr_str(&input, true)
}

fn rep(s: String) -> Result<String, ReaderError> {
    Ok(print(eval(read(s)?)))
}

fn main() {
    loop {
        print!("user> ");
        io::stdout().flush().unwrap();

        let mut input = String::new();
        match io::stdin().read_line(&mut input) {
            Ok(0) => break, // empty line
            Ok(_) => {
                if input == ",q\n" {
                    break;
                }
                match rep(input) {
                    Ok(str) => println!("{}", str),
                    _ => continue,
                }
            }

            Err(_) => println!("Readline error."),
        }
    }
}
