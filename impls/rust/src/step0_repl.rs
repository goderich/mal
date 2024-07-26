// use rustyline;
use std::io;
use std::io::Write;

fn read(s: String) -> String {
    s
}

fn eval(s: String) -> String {
    s
}

fn print(s: String) -> String {
    s
}

fn rep(s: String) -> String {
    print(eval(read(s)))
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
                } else {
                    println!("{}", rep(input))
                }
            }

            Err(error) => println!("error: {error}"),
        }
        // Rustyline version:
        //
        // let mut rl = rustyline::DefaultEditor::new().unwrap();
        // let readline = rl.readline("user> ");
        // match readline {
        //     Ok(line) => {
        //         if line == ",q" {
        //             break;
        //         } else {
        //             println!("{}", rep(line))
        //         }
        //     }
        //     Err(_) => println!("No input"),
        // }
    }
}
