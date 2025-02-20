use memio;
use strconv;

fn pr_str(ast: ast) str = {
	match (ast) {
        case let a: *atom =>
		match (*a) {
		case let n: int =>
			return strconv::itos(n);
                case let s: symbol =>
			return s: str;
		};
        case let list: list =>
		let s = memio::dynamic();
		memio::appendrune(&s, '(')!;
                for (let i = 0z; i < len(list); i += 1) {
			if (i > 0) {
				memio::appendrune(&s, ' ')!;
			};
			memio::concat(&s, pr_str(list[i]))!;
		};
		memio::appendrune(&s, ')')!;
		return memio::string(&s)!;
	};
};
