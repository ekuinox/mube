//! TCP 等のバイトストリーム上でロックコマンドを捌く serve ループ。
//! I/O は `embedded-io-async` のトレイト境界で受けるので、firmware は `TcpSocket` を、
//! テストはメモリ上のモックを渡せる。

use crate::lock::{decide, LockState};
use embedded_io_async::{Read, Write};

/// 1 行の最大バイト数。これを超えて改行が来ない行は不正として読み捨てる。
pub const LINE_MAX: usize = 32;

/// ロック状態の読み書き口。STATUS 用の現在状態取得と、確定状態の永続化＋サーボ駆動を担う。
/// firmware は共有状態（LOCK_STATE）＋サーボ Signal を、テストはメモリ上の mock を実装する。
pub trait LockPort {
    /// STATUS 応答に使う現在のロック状態。
    fn current(&self) -> LockState;
    /// 確定した目標状態を適用する（永続化＋サーボ駆動）。
    fn apply(&self, target: LockState);
}

/// 1 接続を捌く。read が 0 を返す（接続終了）まで、受信を行に切って `decide` し、
/// 応答を書き、サーボ指令があれば `port` へ適用する。read/write エラーはそのまま返す。
pub async fn serve_connection<T, P>(transport: &mut T, port: &P) -> Result<(), T::Error>
where
    T: Read + Write,
    P: LockPort,
{
    let mut line = [0u8; LINE_MAX]; // 組み立て中の行
    let mut len = 0usize; // line の有効バイト数
    let mut overflow = false; // 長すぎ行: 次の改行まで読み捨て
    let mut chunk = [0u8; 64]; // read 用

    loop {
        let n = transport.read(&mut chunk).await?;
        if n == 0 {
            return Ok(()); // 接続終了
        }
        for &b in &chunk[..n] {
            if b == b'\n' {
                if overflow {
                    overflow = false; // 行末まで来たので回復
                } else {
                    let outcome = decide(&line[..len], port.current());
                    transport.write_all(outcome.reply.as_bytes()).await?;
                    if let Some(state) = outcome.servo {
                        port.apply(state);
                    }
                }
                len = 0;
            } else if overflow {
                // 読み捨て
            } else if len < LINE_MAX {
                line[len] = b;
                len += 1;
            } else {
                // 改行が来ないままバッファ満杯 → 長すぎ行
                transport.write_all(b"ERR\n").await?;
                overflow = true;
                len = 0;
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use core::cell::{Cell, RefCell};
    use embassy_futures::block_on;
    use std::vec::Vec;

    /// スクリプトされた read チャンク列を順に返し、尽きたら Ok(0)=EOF。write は out に追記。
    /// 注: 各チャンクは 1 回の read で返す。serve 側の read バッファは 64 バイトなので、
    /// テストのチャンクは 64 バイト以下にすること。
    struct MockTransport {
        chunks: Vec<Vec<u8>>,
        idx: usize,
        out: Vec<u8>,
    }
    impl MockTransport {
        fn new(chunks: &[&[u8]]) -> Self {
            Self {
                chunks: chunks.iter().map(|c| c.to_vec()).collect(),
                idx: 0,
                out: Vec::new(),
            }
        }
    }

    #[derive(Debug)]
    struct MockError;
    impl core::fmt::Display for MockError {
        fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
            write!(f, "MockError")
        }
    }
    impl std::error::Error for MockError {}
    impl embedded_io_async::Error for MockError {
        fn kind(&self) -> embedded_io_async::ErrorKind {
            embedded_io_async::ErrorKind::Other
        }
    }
    impl embedded_io_async::ErrorType for MockTransport {
        type Error = MockError;
    }
    impl Read for MockTransport {
        async fn read(&mut self, buf: &mut [u8]) -> Result<usize, MockError> {
            if self.idx >= self.chunks.len() {
                return Ok(0);
            }
            let chunk = &self.chunks[self.idx];
            self.idx += 1;
            let n = chunk.len().min(buf.len());
            buf[..n].copy_from_slice(&chunk[..n]);
            Ok(n)
        }
    }
    impl Write for MockTransport {
        async fn write(&mut self, buf: &[u8]) -> Result<usize, MockError> {
            self.out.extend_from_slice(buf);
            Ok(buf.len())
        }
        async fn flush(&mut self) -> Result<(), MockError> {
            Ok(())
        }
    }

    struct MockPort {
        state: Cell<LockState>,
        applied: RefCell<Vec<LockState>>,
    }
    impl MockPort {
        fn new(initial: LockState) -> Self {
            Self { state: Cell::new(initial), applied: RefCell::new(Vec::new()) }
        }
    }
    impl LockPort for MockPort {
        fn current(&self) -> LockState {
            self.state.get()
        }
        fn apply(&self, target: LockState) {
            self.state.set(target);
            self.applied.borrow_mut().push(target);
        }
    }

    #[test]
    fn single_command_drives_and_replies() {
        let mut t = MockTransport::new(&[b"UNLOCK\n"]);
        let port = MockPort::new(LockState::Locked);
        block_on(serve_connection(&mut t, &port)).unwrap();
        assert_eq!(&t.out[..], b"UNLOCKED\n");
        assert_eq!(port.applied.borrow().as_slice(), &[LockState::Unlocked]);
    }

    #[test]
    fn status_reflects_current_state() {
        let mut t = MockTransport::new(&[b"STATUS\n"]);
        let port = MockPort::new(LockState::Unlocked);
        block_on(serve_connection(&mut t, &port)).unwrap();
        assert_eq!(&t.out[..], b"UNLOCKED\n");
        assert!(port.applied.borrow().is_empty());
    }

    #[test]
    fn multiple_commands_in_one_read() {
        let mut t = MockTransport::new(&[b"UNLOCK\nSTATUS\nLOCK\n"]);
        let port = MockPort::new(LockState::Locked);
        block_on(serve_connection(&mut t, &port)).unwrap();
        // UNLOCK→UNLOCKED, STATUS→（適用後 Unlocked）UNLOCKED, LOCK→LOCKED
        assert_eq!(&t.out[..], b"UNLOCKED\nUNLOCKED\nLOCKED\n");
        assert_eq!(port.applied.borrow().as_slice(), &[LockState::Unlocked, LockState::Locked]);
    }

    #[test]
    fn line_split_across_reads() {
        let mut t = MockTransport::new(&[b"UNL", b"OCK\n"]);
        let port = MockPort::new(LockState::Locked);
        block_on(serve_connection(&mut t, &port)).unwrap();
        assert_eq!(&t.out[..], b"UNLOCKED\n");
        assert_eq!(port.applied.borrow().as_slice(), &[LockState::Unlocked]);
    }

    #[test]
    fn invalid_line_replies_err_no_drive() {
        let mut t = MockTransport::new(&[b"FOO\n"]);
        let port = MockPort::new(LockState::Locked);
        block_on(serve_connection(&mut t, &port)).unwrap();
        assert_eq!(&t.out[..], b"ERR\n");
        assert!(port.applied.borrow().is_empty());
    }

    #[test]
    fn overlong_line_discarded_then_recovers() {
        let mut over = Vec::new();
        over.extend_from_slice(&[b'A'; 40]);
        over.extend_from_slice(b"\nLOCK\n");
        let mut t = MockTransport::new(&[over.as_slice()]);
        let port = MockPort::new(LockState::Unlocked);
        block_on(serve_connection(&mut t, &port)).unwrap();
        assert_eq!(&t.out[..], b"ERR\nLOCKED\n");
        assert_eq!(port.applied.borrow().as_slice(), &[LockState::Locked]);
    }

    #[test]
    fn crlf_and_lowercase_command() {
        let mut t = MockTransport::new(&[b"unlock\r\n"]);
        let port = MockPort::new(LockState::Locked);
        block_on(serve_connection(&mut t, &port)).unwrap();
        assert_eq!(&t.out[..], b"UNLOCKED\n");
        assert_eq!(port.applied.borrow().as_slice(), &[LockState::Unlocked]);
    }

    #[test]
    fn trailing_bytes_without_newline_not_executed() {
        let mut t = MockTransport::new(&[b"UNLOCK"]);
        let port = MockPort::new(LockState::Locked);
        block_on(serve_connection(&mut t, &port)).unwrap();
        assert!(t.out.is_empty());
        assert!(port.applied.borrow().is_empty());
    }
}
