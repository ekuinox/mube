//! OTA 転送プロトコルの純ロジック（ハード非依存・host テスト対象）。
//! ワイヤ形式: "MUBEOTA1" (8B) + length u32 LE + crc32 u32 LE + ペイロード。
//! firmware 側（受信）と lockctl.ts（送信）の両方がこの契約に従う。

/// フレーム先頭のマジック。
pub const MAGIC: &[u8; 8] = b"MUBEOTA1";
/// 固定長ヘッダのバイト数。
pub const HEADER_LEN: usize = 16;

/// 解析済みヘッダ。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[cfg_attr(feature = "defmt", derive(defmt::Format))]
pub struct Header {
    pub len: u32,
    pub crc32: u32,
}

/// プロトコル違反・検証失敗の種別。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[cfg_attr(feature = "defmt", derive(defmt::Format))]
pub enum OtaError {
    /// マジック不一致。
    BadMagic,
    /// 宣言長がスロット上限を超えている。
    TooLarge { len: u32, max: u32 },
    /// 宣言長を超えるデータを受けた。
    Overrun,
    /// 全量に達しないまま検証された。
    Incomplete { received: u32, expected: u32 },
    /// CRC32 不一致。
    CrcMismatch { expected: u32, actual: u32 },
}

impl OtaError {
    /// ワイヤ応答 "ERR <reason>" 用の短い ASCII 理由。
    pub fn reason(&self) -> &'static str {
        match self {
            OtaError::BadMagic => "bad magic",
            OtaError::TooLarge { .. } => "image too large",
            OtaError::Overrun => "payload overrun",
            OtaError::Incomplete { .. } => "payload incomplete",
            OtaError::CrcMismatch { .. } => "crc mismatch",
        }
    }
}

/// 16 バイトのヘッダを解析する。len が max_len を超えるものは拒否。
pub fn parse_header(buf: &[u8; HEADER_LEN], max_len: u32) -> Result<Header, OtaError> {
    if &buf[..8] != MAGIC {
        return Err(OtaError::BadMagic);
    }
    let len = u32::from_le_bytes(buf[8..12].try_into().unwrap());
    let crc32 = u32::from_le_bytes(buf[12..16].try_into().unwrap());
    if len > max_len {
        return Err(OtaError::TooLarge { len, max: max_len });
    }
    Ok(Header { len, crc32 })
}

/// 逐次 CRC32（IEEE 802.3, reflected, poly 0xEDB88320）。
/// 入力は最大 1MB 級だが受信ペースは TCP 律速のため、テーブルなしのビット直列で足りる。
pub struct Crc32(u32);

impl Crc32 {
    pub fn new() -> Self {
        Self(0xFFFF_FFFF)
    }
    pub fn update(&mut self, data: &[u8]) {
        let mut c = self.0;
        for &byte in data {
            c ^= byte as u32;
            for _ in 0..8 {
                c = if c & 1 != 0 {
                    (c >> 1) ^ 0xEDB8_8320
                } else {
                    c >> 1
                };
            }
        }
        self.0 = c;
    }
    pub fn finalize(&self) -> u32 {
        !self.0
    }
}

impl Default for Crc32 {
    fn default() -> Self {
        Self::new()
    }
}

/// 受信進行の管理。チャンクを accept で受け、全量 + CRC を verify で確定する。
pub struct Receiver {
    header: Header,
    received: u32,
    crc: Crc32,
}

impl Receiver {
    pub fn new(header: Header) -> Self {
        Self {
            header,
            received: 0,
            crc: Crc32::new(),
        }
    }
    /// 残り受信量（バイト）。
    pub fn remaining(&self) -> u32 {
        self.header.len - self.received
    }
    pub fn is_complete(&self) -> bool {
        self.received == self.header.len
    }
    /// チャンクを受理して進行を進める。宣言長超過は Overrun。
    pub fn accept(&mut self, chunk: &[u8]) -> Result<(), OtaError> {
        if chunk.len() as u32 > self.remaining() {
            return Err(OtaError::Overrun);
        }
        self.crc.update(chunk);
        self.received += chunk.len() as u32;
        Ok(())
    }
    /// 全量受信済みかつ CRC 一致なら Ok。
    pub fn verify(&self) -> Result<(), OtaError> {
        if !self.is_complete() {
            return Err(OtaError::Incomplete {
                received: self.received,
                expected: self.header.len,
            });
        }
        let actual = self.crc.finalize();
        if actual != self.header.crc32 {
            return Err(OtaError::CrcMismatch {
                expected: self.header.crc32,
                actual,
            });
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn header_bytes(len: u32, crc: u32) -> [u8; HEADER_LEN] {
        let mut b = [0u8; HEADER_LEN];
        b[..8].copy_from_slice(MAGIC);
        b[8..12].copy_from_slice(&len.to_le_bytes());
        b[12..16].copy_from_slice(&crc.to_le_bytes());
        b
    }

    // 正常なヘッダから len / crc32 をリトルエンディアンで取り出せること
    // （lockctl.ts の buildOtaHeader と対になるワイヤ契約の読み側）。
    #[test]
    fn parse_header_ok() {
        let h = parse_header(&header_bytes(1234, 0xDEADBEEF), 4096).unwrap();
        assert_eq!(
            h,
            Header {
                len: 1234,
                crc32: 0xDEADBEEF
            }
        );
    }

    // マジック不一致（OTA ポートへの無関係な接続や化けたフレーム）を
    // 先頭 8 バイトの時点で拒否できること。
    #[test]
    fn parse_header_bad_magic() {
        let mut b = header_bytes(1, 0);
        b[0] = b'X';
        assert_eq!(parse_header(&b, 4096), Err(OtaError::BadMagic));
    }

    // ACTIVE スロットに収まらない宣言長をヘッダの時点で拒否できること
    // （受信を始める前に弾く = DFU へ 1 バイトも書かない）。
    #[test]
    fn parse_header_too_large() {
        assert_eq!(
            parse_header(&header_bytes(5000, 0), 4096),
            Err(OtaError::TooLarge {
                len: 5000,
                max: 4096
            })
        );
    }

    // CRC32 実装が IEEE 802.3 の標準アルゴリズムに一致すること
    // （"123456789" → 0xCBF43926 は既知の検証ベクタ。lockctl.ts 側と同じ値で契約を固定）。
    #[test]
    fn crc32_known_vector() {
        let mut c = Crc32::new();
        c.update(b"123456789");
        assert_eq!(c.finalize(), 0xCBF43926);
    }

    // 空入力の CRC32 が 0 になること（初期値と反転の組み合わせの退行検知）。
    #[test]
    fn crc32_empty_is_zero() {
        assert_eq!(Crc32::new().finalize(), 0);
    }

    // 分割して update しても一括と同じ CRC になること
    // （受信は TCP のチャンク単位で逐次計算するため、分割不変性が前提になる）。
    #[test]
    fn crc32_split_equals_whole() {
        let mut a = Crc32::new();
        a.update(b"1234");
        a.update(b"56789");
        let mut b = Crc32::new();
        b.update(b"123456789");
        assert_eq!(a.finalize(), b.finalize());
    }

    fn crc_of(data: &[u8]) -> u32 {
        let mut c = Crc32::new();
        c.update(data);
        c.finalize()
    }

    // 分割受信の正常系: TCP のチャンク単位で accept しても remaining / is_complete が
    // 正しく進み、全量受信後に verify（CRC 込み）が成立すること。
    #[test]
    fn receiver_happy_path_in_chunks() {
        let payload = b"hello ota world";
        let h = Header {
            len: payload.len() as u32,
            crc32: crc_of(payload),
        };
        let mut r = Receiver::new(h);
        assert!(!r.is_complete());
        assert_eq!(r.remaining(), payload.len() as u32);
        assert!(r.accept(&payload[..5]).is_ok());
        assert_eq!(r.remaining(), (payload.len() - 5) as u32);
        assert!(r.accept(&payload[5..]).is_ok());
        assert!(r.is_complete());
        assert!(r.verify().is_ok());
    }

    // 宣言長を超えるデータを Overrun として拒否できること
    // （firmware 側で DFU スロットの範囲外書き込みに至らせないための防壁）。
    #[test]
    fn receiver_overrun() {
        let h = Header { len: 4, crc32: 0 };
        let mut r = Receiver::new(h);
        assert_eq!(r.accept(b"12345"), Err(OtaError::Overrun));
    }

    // 全量に達しないまま verify すると Incomplete になること
    // （途中切断のフレームを誤って mark_updated しないための防壁）。
    #[test]
    fn receiver_incomplete_verify_fails() {
        let h = Header { len: 10, crc32: 0 };
        let mut r = Receiver::new(h);
        assert!(r.accept(b"12345").is_ok());
        assert_eq!(
            r.verify(),
            Err(OtaError::Incomplete {
                received: 5,
                expected: 10
            })
        );
    }

    // 全量は受けたが CRC が合わない場合に CrcMismatch になること
    // （化けたイメージを誤って mark_updated しないための防壁）。
    #[test]
    fn receiver_crc_mismatch() {
        let payload = b"abcd";
        let h = Header {
            len: 4,
            crc32: 0x12345678,
        };
        let mut r = Receiver::new(h);
        assert!(r.accept(payload).is_ok());
        assert_eq!(
            r.verify(),
            Err(OtaError::CrcMismatch {
                expected: 0x12345678,
                actual: crc_of(payload)
            })
        );
    }

    // 全エラー種の reason() がワイヤ応答 "ERR <reason>" に載せられる形
    // （非空 ASCII）であることを網羅的に確認する。
    #[test]
    fn error_reasons_are_short_ascii() {
        for e in [
            OtaError::BadMagic,
            OtaError::TooLarge { len: 1, max: 0 },
            OtaError::Overrun,
            OtaError::Incomplete {
                received: 0,
                expected: 1,
            },
            OtaError::CrcMismatch {
                expected: 0,
                actual: 1,
            },
        ] {
            assert!(e.reason().is_ascii() && !e.reason().is_empty());
        }
    }
}
