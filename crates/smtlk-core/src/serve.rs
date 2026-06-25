//! TCP 等のバイトストリーム上でロックコマンドを捌く serve ループ。
//! I/O は `embedded-io-async` のトレイト境界で受けるので、firmware は `TcpSocket` を、
//! テストはメモリ上のモックを渡せる。

use crate::lock::{LockController, LockState};
use embedded_io_async::{Read, Write};

/// 1 行の最大バイト数。これを超えて改行が来ない行は不正として読み捨てる。
pub const LINE_MAX: usize = 32;

/// サーボへ駆動状態を渡す同期の口。firmware は `Signal::signal` を、テストは記録用を実装する。
pub trait ServoSink {
    fn send(&self, state: LockState);
}

/// 1 接続を捌く。read が 0 を返す（接続終了）まで、受信を行に切って `handle_line` し、
/// 応答を書き、サーボ指令があれば `sink` へ送る。read/write エラーはそのまま返す。
pub async fn serve_connection<T, S>(
    transport: &mut T,
    controller: &mut LockController,
    sink: &S,
) -> Result<(), T::Error>
where
    T: Read + Write,
    S: ServoSink,
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
                    let outcome = controller.handle_line(&line[..len]);
                    transport.write_all(outcome.reply.as_bytes()).await?;
                    if let Some(state) = outcome.servo {
                        sink.send(state);
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
    use crate::lock::LockController;
    use core::cell::RefCell;
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

    struct MockSink {
        sent: RefCell<Vec<LockState>>,
    }
    impl MockSink {
        fn new() -> Self {
            Self { sent: RefCell::new(Vec::new()) }
        }
    }
    impl ServoSink for MockSink {
        fn send(&self, state: LockState) {
            self.sent.borrow_mut().push(state);
        }
    }

    #[test]
    fn single_command_drives_and_replies() {
        let mut t = MockTransport::new(&[b"UNLOCK\n"]);
        let mut ctrl = LockController::new();
        let sink = MockSink::new();
        block_on(serve_connection(&mut t, &mut ctrl, &sink)).unwrap();
        assert_eq!(&t.out[..], b"UNLOCKED\n");
        assert_eq!(sink.sent.borrow().as_slice(), &[LockState::Unlocked]);
    }

    #[test]
    fn multiple_commands_in_one_read() {
        let mut t = MockTransport::new(&[b"UNLOCK\nSTATUS\nLOCK\n"]);
        let mut ctrl = LockController::new();
        let sink = MockSink::new();
        block_on(serve_connection(&mut t, &mut ctrl, &sink)).unwrap();
        // UNLOCK→UNLOCKED, STATUS→（現状態 Unlocked）UNLOCKED, LOCK→LOCKED
        assert_eq!(&t.out[..], b"UNLOCKED\nUNLOCKED\nLOCKED\n");
        // STATUS は駆動しないので Unlocked, Locked の 2 件だけ
        assert_eq!(
            sink.sent.borrow().as_slice(),
            &[LockState::Unlocked, LockState::Locked]
        );
    }

    #[test]
    fn line_split_across_reads() {
        let mut t = MockTransport::new(&[b"UNL", b"OCK\n"]);
        let mut ctrl = LockController::new();
        let sink = MockSink::new();
        block_on(serve_connection(&mut t, &mut ctrl, &sink)).unwrap();
        assert_eq!(&t.out[..], b"UNLOCKED\n");
        assert_eq!(sink.sent.borrow().as_slice(), &[LockState::Unlocked]);
    }

    #[test]
    fn invalid_line_replies_err_no_drive() {
        let mut t = MockTransport::new(&[b"FOO\n"]);
        let mut ctrl = LockController::new();
        let sink = MockSink::new();
        block_on(serve_connection(&mut t, &mut ctrl, &sink)).unwrap();
        assert_eq!(&t.out[..], b"ERR\n");
        assert!(sink.sent.borrow().is_empty());
    }

    #[test]
    fn overlong_line_discarded_then_recovers() {
        // 40 バイトの無改行（LINE_MAX=32 超）→ ERR、その後の正常行は処理される
        let mut over = Vec::new();
        over.extend_from_slice(&[b'A'; 40]);
        over.extend_from_slice(b"\nLOCK\n");
        let mut t = MockTransport::new(&[over.as_slice()]);
        let mut ctrl = LockController::new();
        let sink = MockSink::new();
        block_on(serve_connection(&mut t, &mut ctrl, &sink)).unwrap();
        assert_eq!(&t.out[..], b"ERR\nLOCKED\n");
        assert_eq!(sink.sent.borrow().as_slice(), &[LockState::Locked]);
    }

    #[test]
    fn trailing_bytes_without_newline_not_executed() {
        let mut t = MockTransport::new(&[b"UNLOCK"]); // 末尾改行なしで EOF
        let mut ctrl = LockController::new();
        let sink = MockSink::new();
        block_on(serve_connection(&mut t, &mut ctrl, &sink)).unwrap();
        assert!(t.out.is_empty());
        assert!(sink.sent.borrow().is_empty());
    }
}
