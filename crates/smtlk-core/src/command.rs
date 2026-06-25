//! 受信バイト列のコマンド解釈。前後 ASCII 空白をトリムし大小文字無視。

/// 受理するコマンド。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Command {
    Lock,
    Unlock,
    Status,
}

/// 1 行をコマンドへ。前後 ASCII 空白をトリムし大小文字無視。不正は None。
pub fn parse(line: &[u8]) -> Option<Command> {
    let t = trim_ascii(line);
    if eq_ignore_case(t, b"LOCK") {
        Some(Command::Lock)
    } else if eq_ignore_case(t, b"UNLOCK") {
        Some(Command::Unlock)
    } else if eq_ignore_case(t, b"STATUS") {
        Some(Command::Status)
    } else {
        None
    }
}

fn trim_ascii(mut s: &[u8]) -> &[u8] {
    while let [first, rest @ ..] = s {
        if first.is_ascii_whitespace() {
            s = rest;
        } else {
            break;
        }
    }
    while let [rest @ .., last] = s {
        if last.is_ascii_whitespace() {
            s = rest;
        } else {
            break;
        }
    }
    s
}

fn eq_ignore_case(a: &[u8], b: &[u8]) -> bool {
    a.len() == b.len() && a.iter().zip(b).all(|(x, y)| x.eq_ignore_ascii_case(y))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_basic() {
        assert_eq!(parse(b"LOCK\n"), Some(Command::Lock));
        assert_eq!(parse(b"UNLOCK\r\n"), Some(Command::Unlock));
        assert_eq!(parse(b"STATUS\n"), Some(Command::Status));
    }

    #[test]
    fn case_insensitive_and_trimmed() {
        assert_eq!(parse(b"lock\n"), Some(Command::Lock));
        assert_eq!(parse(b"  STATUS  \n"), Some(Command::Status));
    }

    #[test]
    fn rejects_unknown_and_empty() {
        assert_eq!(parse(b""), None);
        assert_eq!(parse(b"FOO\n"), None);
        assert_eq!(parse(b"LOCKED\n"), None);
    }
}
