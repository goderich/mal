use bufio;
use fmt;
use io;
use os;
use strings;

export fn main() void = {
	fmt::println("MAL-on-Hare version 0.0.1")!;
	let in_line: []u8 = [];
	defer free(in_line);

	for (true) {
		fmt::print("user> ")!;
        bufio::flush(os::stdout)!;
		in_line = match (bufio::read_line(os::stdin)!) {
			case let line: []u8 =>
				yield line;
			case io::EOF =>
				break;
		};
		const result = rep(strings::fromutf8(in_line)!);
		fmt::println(result)!;
		free(result);
	};
    
	fmt::println("\nExiting...")!;
};

fn rep(s: str) str = {
	const r = READ(s);
	const e = EVAL(r);
	const p = PRINT(e);
	return p;
};

fn READ(s: str) ast = {
	return read_str(s);
};

fn EVAL(a: ast) ast = {
	return a;
};

fn PRINT(a: ast) str = {
	return pr_str(a);
};
