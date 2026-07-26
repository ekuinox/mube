# ファーム OTA（embassy-boot A/B）実装プラン

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** LAN 内から `just ota` 一発で Pico W ファームを更新でき、壊れたファームは自動ロールバックする。

**Architecture:** embassy-boot-rp のブートローダー（新クレート mube-boot）が 2MB フラッシュを ACTIVE/DFU/STATE に分割し A/B スワップを担う。アプリは TCP 4242 の専用リスナーで新イメージを受けて DFU に逐次書き込み、mark_updated → リセット。ヘルス条件（WiFi + HTTP + サーボ初期化）到達で mark_booted、未到達は watchdog リセット → ブートローダーが revert。プロトコルの純ロジック（ヘッダ・CRC32・進行管理）は mube-core に置き host テストする。

**Tech Stack:** embassy-boot-rp 0.10 / embassy-rp 0.10 / embassy-net 0.9（いずれも既存版と整合を確認済み）、bun (lockctl.ts)、rust-objcopy (llvm-tools + cargo-binutils)

**Spec:** `docs/superpowers/specs/2026-07-26-firmware-ota-embassy-boot-design.md`（必読）

## Global Constraints

- コマンド実行は常に `nix develop -c` 前置（この開発機の非対話シェルに cargo/bun/just が無い）。作業ディレクトリはリポジトリルート。
- Rust 変更後は `nix develop -c cargo host-test` を通してからコミット（CLAUDE.md 規約）。
- firmware のビルドは WebUI が先: `nix develop -c just firmware`（blobs → webui → cargo build）。素の `cargo build` は dist が無いと build.rs が明示エラーで落ちる。
- `--workspace` / `--all-targets` 付き cargo は禁止（webui が thumbv6m に乗って失敗する。ワークスペース Cargo.toml のコメント参照）。
- WiFi 実値・CYW43 ブロブはコミット禁止。会話・コミットに実値を載せない。
- フラッシュレイアウト（spec と一致させる）: ブートローダー 0x10000000+28KB / STATE 0x10007000+4KB / ACTIVE 0x10008000+988KB / DFU 0x100FF000+992KB。
- OTA ポートは TCP 4242。プロトコルは `MUBEOTA1`(8B) + length u32 LE + crc32 u32 LE + ペイロード。応答は `OK <len>\n` / `ERR <reason>\n`。
- 実機（DAP・Pico W）はこのセッションからは触れない。実機検証はお兄ちゃんの手作業として docs に手順を残す。

## 事前確認済みの事実（実装者向け）

- 現行 release ビルドのフラッシュ搭載分は約 532KB（ACTIVE 988KB の 54%）。サイズは問題ない。
- embassy-boot-rp 0.10.0 の依存: embassy-boot 0.7 / embassy-rp ^0.10 / embassy-sync ^0.8 / embassy-time ^0.5 — すべて既存 Cargo.toml と同版系。
- rust-toolchain.toml に `llvm-tools` コンポーネントは追加済み（`rust-objcopy` のラッパー `cargo-binutils` だけ devShell に足す必要がある）。
- DMA_CH0 は cyw43 PIO-SPI が使用中。フラッシュ Async 用には DMA_CH1 を使う。
- embassy-boot の API 詳細（`BootLoader::prepare` / `FirmwareUpdater` のシグネチャ、`AlignedBuffer` のサイズ）は本プランのコードを出発点にし、コンパイルエラーが出たら docs.rs の embassy-boot-rp 0.10.0 トップページと embassy リポジトリ `examples/boot/{bootloader,application}/rp/src/main.rs`（タグ embassy-boot-rp-v0.10.0 付近）を正とする。

---

### Task 1: mube-core に OTA プロトコルの純ロジック（TDD）

**Files:**
- Create: `crates/mube-core/src/ota.rs`
- Modify: `crates/mube-core/src/lib.rs`（`pub mod ota;` 追加）

**Interfaces:**
- Produces（Task 4 と Task 5 が依存）:
  - `mube_core::ota::{MAGIC: &[u8;8], HEADER_LEN: usize = 16}`
  - `parse_header(buf: &[u8; 16], max_len: u32) -> Result<Header, OtaError>`
  - `struct Header { pub len: u32, pub crc32: u32 }`
  - `struct Crc32` — `new()`, `update(&mut self, &[u8])`, `finalize(&self) -> u32`（IEEE reflected, poly 0xEDB88320）
  - `struct Receiver` — `new(Header)`, `accept(&mut self, &[u8]) -> Result<(), OtaError>`, `remaining(&self) -> u32`, `is_complete(&self) -> bool`, `verify(&self) -> Result<(), OtaError>`
  - `enum OtaError { BadMagic, TooLarge { len: u32, max: u32 }, Overrun, Incomplete { received: u32, expected: u32 }, CrcMismatch { expected: u32, actual: u32 } }` と `fn reason(&self) -> &'static str`（ワイヤ応答 `ERR <reason>` 用の短い ASCII）

- [ ] **Step 1: 失敗するテストを書く**

`crates/mube-core/src/ota.rs` を作成し、まず実装は空のまま（コンパイルが通る最小のスタブすら書かず）テストだけ書く…はコンパイルできないので、Rust の流儀に合わせ「スタブ + テスト」を同時に置き、テストが**落ちる**ことを確認してから実装する。スタブは `todo!()` を使う:

```rust
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
        todo!()
    }
}

/// 16 バイトのヘッダを解析する。len が max_len を超えるものは拒否。
pub fn parse_header(buf: &[u8; HEADER_LEN], max_len: u32) -> Result<Header, OtaError> {
    todo!()
}

/// 逐次 CRC32（IEEE 802.3, reflected, poly 0xEDB88320）。
pub struct Crc32(u32);

impl Crc32 {
    pub fn new() -> Self {
        todo!()
    }
    pub fn update(&mut self, data: &[u8]) {
        todo!()
    }
    pub fn finalize(&self) -> u32 {
        todo!()
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
        todo!()
    }
    /// 残り受信量（バイト）。
    pub fn remaining(&self) -> u32 {
        todo!()
    }
    pub fn is_complete(&self) -> bool {
        todo!()
    }
    /// チャンクを受理して進行を進める。宣言長超過は Overrun。
    pub fn accept(&mut self, chunk: &[u8]) -> Result<(), OtaError> {
        todo!()
    }
    /// 全量受信済みかつ CRC 一致なら Ok。
    pub fn verify(&self) -> Result<(), OtaError> {
        todo!()
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

    #[test]
    fn parse_header_ok() {
        let h = parse_header(&header_bytes(1234, 0xDEADBEEF), 4096).unwrap();
        assert_eq!(h, Header { len: 1234, crc32: 0xDEADBEEF });
    }

    #[test]
    fn parse_header_bad_magic() {
        let mut b = header_bytes(1, 0);
        b[0] = b'X';
        assert_eq!(parse_header(&b, 4096), Err(OtaError::BadMagic));
    }

    #[test]
    fn parse_header_too_large() {
        assert_eq!(
            parse_header(&header_bytes(5000, 0), 4096),
            Err(OtaError::TooLarge { len: 5000, max: 4096 })
        );
    }

    #[test]
    fn crc32_known_vector() {
        // IEEE CRC32 の標準テストベクタ
        let mut c = Crc32::new();
        c.update(b"123456789");
        assert_eq!(c.finalize(), 0xCBF43926);
    }

    #[test]
    fn crc32_empty_is_zero() {
        assert_eq!(Crc32::new().finalize(), 0);
    }

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

    #[test]
    fn receiver_happy_path_in_chunks() {
        let payload = b"hello ota world";
        let h = Header { len: payload.len() as u32, crc32: crc_of(payload) };
        let mut r = Receiver::new(h);
        assert!(!r.is_complete());
        assert_eq!(r.remaining(), payload.len() as u32);
        r.accept(&payload[..5]).unwrap();
        assert_eq!(r.remaining(), (payload.len() - 5) as u32);
        r.accept(&payload[5..]).unwrap();
        assert!(r.is_complete());
        r.verify().unwrap();
    }

    #[test]
    fn receiver_overrun() {
        let h = Header { len: 4, crc32: 0 };
        let mut r = Receiver::new(h);
        assert_eq!(r.accept(b"12345"), Err(OtaError::Overrun));
    }

    #[test]
    fn receiver_incomplete_verify_fails() {
        let h = Header { len: 10, crc32: 0 };
        let mut r = Receiver::new(h);
        r.accept(b"12345").unwrap();
        assert_eq!(r.verify(), Err(OtaError::Incomplete { received: 5, expected: 10 }));
    }

    #[test]
    fn receiver_crc_mismatch() {
        let payload = b"abcd";
        let h = Header { len: 4, crc32: 0x12345678 };
        let mut r = Receiver::new(h);
        r.accept(payload).unwrap();
        assert_eq!(
            r.verify(),
            Err(OtaError::CrcMismatch { expected: 0x12345678, actual: crc_of(payload) })
        );
    }

    #[test]
    fn error_reasons_are_short_ascii() {
        for e in [
            OtaError::BadMagic,
            OtaError::TooLarge { len: 1, max: 0 },
            OtaError::Overrun,
            OtaError::Incomplete { received: 0, expected: 1 },
            OtaError::CrcMismatch { expected: 0, actual: 1 },
        ] {
            assert!(e.reason().is_ascii() && !e.reason().is_empty());
        }
    }
}
```

`crates/mube-core/src/lib.rs` に `pub mod ota;` を追加（既存の `pub mod webapi;` の後ろ）。

- [ ] **Step 2: テストが落ちることを確認**

Run: `nix develop -c cargo host-test`
Expected: FAIL（`todo!()` による panic 群）

- [ ] **Step 3: 実装を書く**

`todo!()` を以下で置き換える:

```rust
impl OtaError {
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

impl Crc32 {
    pub fn new() -> Self {
        Self(0xFFFF_FFFF)
    }

    pub fn update(&mut self, data: &[u8]) {
        let mut c = self.0;
        for &byte in data {
            c ^= byte as u32;
            for _ in 0..8 {
                c = if c & 1 != 0 { (c >> 1) ^ 0xEDB8_8320 } else { c >> 1 };
            }
        }
        self.0 = c;
    }

    pub fn finalize(&self) -> u32 {
        !self.0
    }
}

impl Receiver {
    pub fn new(header: Header) -> Self {
        Self { header, received: 0, crc: Crc32::new() }
    }

    pub fn remaining(&self) -> u32 {
        self.header.len - self.received
    }

    pub fn is_complete(&self) -> bool {
        self.received == self.header.len
    }

    pub fn accept(&mut self, chunk: &[u8]) -> Result<(), OtaError> {
        if chunk.len() as u32 > self.remaining() {
            return Err(OtaError::Overrun);
        }
        self.crc.update(chunk);
        self.received += chunk.len() as u32;
        Ok(())
    }

    pub fn verify(&self) -> Result<(), OtaError> {
        if !self.is_complete() {
            return Err(OtaError::Incomplete { received: self.received, expected: self.header.len });
        }
        let actual = self.crc.finalize();
        if actual != self.header.crc32 {
            return Err(OtaError::CrcMismatch { expected: self.header.crc32, actual });
        }
        Ok(())
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `nix develop -c cargo host-test`
Expected: PASS（既存テスト含め全緑）

- [ ] **Step 5: コミット**

```bash
git add crates/mube-core/src/ota.rs crates/mube-core/src/lib.rs
git commit -m "mube-core: OTA 転送プロトコルの純ロジック（ヘッダ・CRC32・受信管理）"
```

---

### Task 2: /api/version（更新確認用のバージョン埋め込み）

**Files:**
- Modify: `crates/mube-firmware/build.rs`（git describe を環境変数へ）
- Modify: `crates/mube-firmware/src/http.rs`（`/api/version` ルート追加）
- Modify: `docs/firmware.md`（JSON API 表に 1 行追加）

**Interfaces:**
- Produces: `GET /api/version` → `{"version":"<git describe --always --dirty>"}`（Task 5 の lockctl がポーリングする）

- [ ] **Step 1: build.rs に MUBE_VERSION の埋め込みを追加**

`crates/mube-firmware/build.rs` の `fn main()` 末尾（dist チェックの後）に追加:

```rust
    // 更新が反映されたかを /api/version で確認できるよう、git describe を埋め込む。
    // .git が無い環境（tarball 等）でもビルドできるよう "unknown" へフォールバック。
    let version = std::process::Command::new("git")
        .args(["describe", "--always", "--dirty"])
        .output()
        .ok()
        .filter(|o| o.status.success())
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .unwrap_or_else(|| "unknown".to_string());
    println!("cargo:rustc-env=MUBE_VERSION={version}");
    // HEAD の移動（コミット・ブランチ切替）で再実行し、バージョンの陳腐化を防ぐ。
    // linked worktree では .git がファイルのため、実体は rev-parse で解決する。
    if let Some(git_dir) = std::process::Command::new("git")
        .args(["rev-parse", "--absolute-git-dir"])
        .output()
        .ok()
        .filter(|o| o.status.success())
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
    {
        println!("cargo:rerun-if-changed={git_dir}/HEAD");
    }
```

- [ ] **Step 2: http.rs にルートを追加**

`crates/mube-firmware/src/http.rs`:

```rust
// 定数群（CT_JSON の近く）に追加:
/// build.rs が git describe から埋めるファームバージョン（JSON 形に固めて埋め込む）。
const VERSION_JSON: &str = concat!("{\"version\":\"", env!("MUBE_VERSION"), "\"}");
```

`make_app()` のルート列に追加:

```rust
        .route("/api/version", get(|| async { json(VERSION_JSON) }))
```

- [ ] **Step 3: ビルドで検証**

Run: `nix develop -c just firmware`
Expected: 成功。（バージョン文字列はコンパイル時埋め込みなので、実機なしではビルド成功までが検証範囲）

- [ ] **Step 4: docs の API 表を更新**

`docs/firmware.md` の JSON API 表に追加:

```markdown
| `/api/version` | GET | `{"version":"f90217f"}`（git describe。更新の反映確認用） |
```

- [ ] **Step 5: host テスト回帰確認 + コミット**

Run: `nix develop -c cargo host-test`
Expected: PASS

```bash
git add crates/mube-firmware/build.rs crates/mube-firmware/src/http.rs docs/firmware.md
git commit -m "firmware: /api/version 追加（git describe をビルド時埋め込み）"
```

---

### Task 3: mube-boot クレート（ブートローダー）とフラッシュレイアウト

**Files:**
- Create: `crates/mube-boot/Cargo.toml`
- Create: `crates/mube-boot/build.rs`
- Create: `crates/mube-boot/memory.x`
- Create: `crates/mube-boot/src/main.rs`
- Modify: `crates/mube-firmware/memory.x`（FLASH 原点を ACTIVE へ、STATE/DFU 領域とシンボル追加）
- Modify: `Cargo.toml`（workspace の default-members に mube-boot 追加）

**Interfaces:**
- Consumes: なし（独立バイナリ）
- Produces: フラッシュレイアウト（Global Constraints の値）と、リンカシンボル `__bootloader_state_start/end`・`__bootloader_dfu_start/end`（Task 4 の `FirmwareUpdaterConfig::from_linkerfile` が参照）

- [ ] **Step 1: mube-boot クレートを作る**

`crates/mube-boot/Cargo.toml`:

```toml
[package]
name = "mube-boot"
version.workspace = true
edition.workspace = true
rust-version.workspace = true
license.workspace = true
description = "embassy-boot bootloader for mube — A/B swap + watchdog rollback"

[dependencies]
embassy-boot-rp = "0.10"
embassy-rp = { version = "0.10", features = ["rp2040", "critical-section-impl", "time-driver", "unstable-pac"] }
embassy-sync = "0.8"
embassy-time = "0.5"
cortex-m = { version = "0.7", features = ["inline-asm"] }
cortex-m-rt = "0.7"
```

`crates/mube-boot/build.rs`（mube-firmware の build.rs と同構成。defmt は使わないので -Tdefmt.x は付けない）:

```rust
//! ブートローダーのメモリレイアウトをリンカに渡す。embassy examples/boot/bootloader/rp と同等。

use std::env;
use std::fs::File;
use std::io::Write;
use std::path::PathBuf;

fn main() {
    let out = &PathBuf::from(env::var_os("OUT_DIR").unwrap());
    File::create(out.join("memory.x"))
        .unwrap()
        .write_all(include_bytes!("memory.x"))
        .unwrap();
    println!("cargo:rustc-link-search={}", out.display());
    println!("cargo:rerun-if-changed=memory.x");
    println!("cargo:rerun-if-changed=build.rs");

    println!("cargo:rustc-link-arg-bins=--nmagic");
    println!("cargo:rustc-link-arg-bins=-Tlink.x"); // cortex-m-rt
    println!("cargo:rustc-link-arg-bins=-Tlink-rp.x"); // embassy-rp (boot2 等)
}
```

`crates/mube-boot/memory.x`（レイアウトの単一ソース。**アプリ側 memory.x と数値を一致させること**）:

```
/* mube の OTA フラッシュレイアウト（2MB QSPI）。
   spec: docs/superpowers/specs/2026-07-26-firmware-ota-embassy-boot-design.md
   embassy-boot の from_linkerfile が末尾のシンボル群を読む。 */
MEMORY
{
    BOOT2            : ORIGIN = 0x10000000, LENGTH = 0x100
    FLASH            : ORIGIN = 0x10000100, LENGTH = 28K - 0x100
    BOOTLOADER_STATE : ORIGIN = 0x10007000, LENGTH = 4K
    ACTIVE           : ORIGIN = 0x10008000, LENGTH = 988K
    DFU              : ORIGIN = 0x100FF000, LENGTH = 992K
    RAM              : ORIGIN = 0x20000000, LENGTH = 256K
}

__bootloader_state_start = ORIGIN(BOOTLOADER_STATE) - ORIGIN(BOOT2);
__bootloader_state_end   = ORIGIN(BOOTLOADER_STATE) + LENGTH(BOOTLOADER_STATE) - ORIGIN(BOOT2);

__bootloader_active_start = ORIGIN(ACTIVE) - ORIGIN(BOOT2);
__bootloader_active_end   = ORIGIN(ACTIVE) + LENGTH(ACTIVE) - ORIGIN(BOOT2);

__bootloader_dfu_start = ORIGIN(DFU) - ORIGIN(BOOT2);
__bootloader_dfu_end   = ORIGIN(DFU) + LENGTH(DFU) - ORIGIN(BOOT2);
```

`crates/mube-boot/src/main.rs`:

```rust
//! mube ブートローダー。embassy-boot-rp の A/B スワップをそのまま使う薄い殻。
//! swap/revert 中の電源断からも回復できるよう watchdog 付きフラッシュで動く。
//! ロジックは持たない（持つとブートローダー自身の更新が必要になる）。

#![no_std]
#![no_main]

use core::cell::RefCell;

use cortex_m_rt::entry;
use embassy_boot_rp::{BootLoader, BootLoaderConfig, WatchdogFlash};
use embassy_sync::blocking_mutex::Mutex;
use embassy_time::Duration;

const FLASH_SIZE: usize = 2 * 1024 * 1024;

#[entry]
fn main() -> ! {
    let p = embassy_rp::init(Default::default());

    // swap は数十秒かかりうる。WatchdogFlash がフラッシュ操作のたびに餌をやるため、
    // 途中の電源断・ハングでも次回起動で作業を再開できる。
    let flash = WatchdogFlash::<FLASH_SIZE>::start(p.FLASH, p.WATCHDOG, Duration::from_secs(8));
    let flash = Mutex::new(RefCell::new(flash));

    let config = BootLoaderConfig::from_linkerfile_blocking(&flash, &flash, &flash);
    let active_offset = config.active.offset();
    let bl: BootLoader = BootLoader::prepare(config);

    unsafe { bl.load(embassy_rp::flash::FLASH_BASE as u32 + active_offset) }
}

#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    // ここに来たら watchdog リセットに任せる（udf でハードフォルト → 8 秒で再起動）。
    cortex_m::asm::udf()
}
```

コンパイルエラーが出たら「事前確認済みの事実」の最終項の一次情報（docs.rs / embassy examples の該当タグ）に合わせて修正する。`BootLoader` の型パラメータ（バッファサイズ等）は 0.10 の例に従う。

- [ ] **Step 2: ワークスペースに追加**

ルート `Cargo.toml` の default-members を変更:

```toml
default-members = ["crates/mube-firmware", "crates/mube-core", "crates/mube-boot"]
```

（members は `crates/*` グロブなので追記不要）

- [ ] **Step 3: アプリの memory.x を ACTIVE 起点へ変更**

`crates/mube-firmware/memory.x` を全置換:

```
/* RP2040 (Pico W) の OTA レイアウト。アプリは ACTIVE スロットから XIP 実行される。
   ブートローダー（crates/mube-boot）を先に焼いておくこと（焼き方は docs/firmware.md）。
   レイアウトの単一ソースは crates/mube-boot/memory.x。数値を必ず一致させる。
   BOOT2 領域は link-rp.x の .boot2 配置先として必要（probe-rs はブートローダーと
   同一内容を書くだけで無害。OTA バイナリからは objcopy --remove-section .boot2 で外す）。 */
MEMORY
{
    BOOT2            : ORIGIN = 0x10000000, LENGTH = 0x100
    FLASH            : ORIGIN = 0x10008000, LENGTH = 988K
    BOOTLOADER_STATE : ORIGIN = 0x10007000, LENGTH = 4K
    DFU              : ORIGIN = 0x100FF000, LENGTH = 992K
    RAM              : ORIGIN = 0x20000000, LENGTH = 256K
}

__bootloader_state_start = ORIGIN(BOOTLOADER_STATE) - ORIGIN(BOOT2);
__bootloader_state_end   = ORIGIN(BOOTLOADER_STATE) + LENGTH(BOOTLOADER_STATE) - ORIGIN(BOOT2);

__bootloader_dfu_start = ORIGIN(DFU) - ORIGIN(BOOT2);
__bootloader_dfu_end   = ORIGIN(DFU) + LENGTH(DFU) - ORIGIN(BOOT2);
```

- [ ] **Step 4: ビルドで検証**

Run: `nix develop -c just firmware`
Expected: 成功（mube-boot と mube-firmware の両方がビルドされる）

Run: `nix develop -c bash -c 'readelf -l target/thumbv6m-none-eabi/debug/mube-firmware | grep LOAD'`
Expected: LOAD セグメントの PhysAddr が 0x10008000 以降（boot2 の 0x10000000 を除く）に載っている

Run: `nix develop -c bash -c 'readelf -l target/thumbv6m-none-eabi/debug/mube-boot | grep LOAD'`
Expected: 0x10000000〜0x10007000 の範囲に収まっている

- [ ] **Step 5: host テスト回帰確認 + コミット**

Run: `nix develop -c cargo host-test`
Expected: PASS

```bash
git add crates/mube-boot Cargo.toml Cargo.lock crates/mube-firmware/memory.x
git commit -m "mube-boot: embassy-boot ブートローダー追加、フラッシュを A/B レイアウトへ分割"
```

---

### Task 4: firmware の OTA 受信タスク・watchdog・mark_booted

**Files:**
- Create: `crates/mube-firmware/src/ota.rs`
- Modify: `crates/mube-firmware/src/main.rs`
- Modify: `crates/mube-firmware/Cargo.toml`

**Interfaces:**
- Consumes: Task 1 の `mube_core::ota::*`、Task 3 のリンカシンボル
- Produces: TCP 4242 の OTA 受信口（Task 5 の lockctl が接続）、`crate::OtaFlash` 型と `crate::FLASH_SIZE`

- [ ] **Step 1: Cargo.toml に依存と feature を追加**

`crates/mube-firmware/Cargo.toml` の `[dependencies]` に追加:

```toml
embassy-boot-rp = { version = "0.10", features = ["defmt"] }
```

`[features]` セクションを新設（ファイル末尾）:

```toml
[features]
# OTA ロールバックの実機試験用: 起動直後に意図的に panic する「壊れたファーム」を作る。
# 使い方は docs/firmware.md の OTA 節を参照。通常ビルドでは絶対に有効にしないこと。
ota-rollback-test = []
```

- [ ] **Step 2: ota.rs（受信タスク）を作る**

`crates/mube-firmware/src/ota.rs`:

```rust
//! OTA 受信: TCP 4242 で MUBEOTA1 フレームを受け、DFU パーティションへ逐次書き込む。
//! プロトコル判定・CRC は mube_core::ota（host テスト済み）に委ね、ここはソケットと
//! フラッシュをつなぐアダプタに徹する。
//!
//! 受信中も ACTIVE スロットには一切触れないため、切断・電源断はいつでも安全。
//! 全量受信 + CRC 一致のときだけ mark_updated → リセットし、ブートローダーに
//! スワップさせる。新ファームがヘルス条件に達しなければ watchdog + revert で戻る。

use core::fmt::Write as _;

use defmt::{info, warn};
use embassy_boot_rp::{AlignedBuffer, FirmwareUpdater, FirmwareUpdaterConfig};
use embassy_net::tcp::TcpSocket;
use embassy_time::{Duration, Timer};
use heapless::String;
use mube_core::ota::{parse_header, OtaError, Receiver, HEADER_LEN};

/// OTA 受信の TCP ポート。lockctl.ts と合わせる。
pub const OTA_PORT: u16 = 4242;

/// 受理する最大イメージ長 = ACTIVE スロット長（memory.x と一致させる）。
const MAX_IMAGE_LEN: u32 = 988 * 1024;

/// フラッシュ書き込み単位。消去セクタ（4KB）に合わせ、write_firmware が
/// セクタ境界ごとに消去できるようにする。
const WRITE_CHUNK: usize = 4096;

/// 受信失敗の内訳（応答文字列の生成に使う）。
enum OtaFail {
    Protocol(OtaError),
    Socket,
    Flash,
}

impl OtaFail {
    fn reason(&self) -> &'static str {
        match self {
            OtaFail::Protocol(e) => e.reason(),
            OtaFail::Socket => "socket error",
            OtaFail::Flash => "flash write failed",
        }
    }
}

#[embassy_executor::task]
pub async fn ota_task(stack: embassy_net::Stack<'static>, flash: &'static crate::OtaFlash) -> ! {
    // rx はフラッシュ書き込み単位より大きくして TCP を止めにくくする。tx は 1 行応答のみ。
    let mut rx_buf = [0u8; 4096];
    let mut tx_buf = [0u8; 256];
    loop {
        let mut socket = TcpSocket::new(stack, &mut rx_buf, &mut tx_buf);
        // 転送停滞（クライアント死）でタスクが永久に塞がらないように。
        socket.set_timeout(Some(Duration::from_secs(30)));
        if socket.accept(OTA_PORT).await.is_err() {
            continue;
        }
        info!("ota: client connected");
        match receive_image(&mut socket, flash).await {
            Ok(len) => {
                info!("ota: image received ({} bytes), swapping on next boot", len);
                let mut line: String<32> = String::new();
                let _ = write!(line, "OK {}\n", len);
                let _ = socket.write_all(line.as_bytes()).await;
                let _ = socket.flush().await;
                socket.close();
                // サーボのワンショット駆動（SETTLE_MS オーダー）を巻き込まない猶予を
                // 置いてからリセットし、ブートローダーにスワップさせる。
                Timer::after(Duration::from_secs(2)).await;
                cortex_m::peripheral::SCB::sys_reset();
            }
            Err(fail) => {
                warn!("ota: failed: {}", fail.reason());
                let mut line: String<64> = String::new();
                let _ = write!(line, "ERR {}\n", fail.reason());
                let _ = socket.write_all(line.as_bytes()).await;
                let _ = socket.flush().await;
                socket.close();
                // ソケットのクローズ処理を進めてから次の接続を待つ。
                Timer::after(Duration::from_millis(100)).await;
            }
        }
    }
}

/// ヘッダ受信 → DFU への逐次書き込み → 検証 → mark_updated までを行う。
/// Err はプロトコル違反・ソケット断・フラッシュ失敗のいずれか（ACTIVE は無傷）。
async fn receive_image(
    socket: &mut TcpSocket<'_>,
    flash: &'static crate::OtaFlash,
) -> Result<u32, OtaFail> {
    let mut header_buf = [0u8; HEADER_LEN];
    read_exact(socket, &mut header_buf).await?;
    let header = parse_header(&header_buf, MAX_IMAGE_LEN).map_err(OtaFail::Protocol)?;
    info!("ota: header ok, expecting {} bytes", header.len);

    let config = FirmwareUpdaterConfig::from_linkerfile(flash, flash);
    let mut aligned = AlignedBuffer([0; embassy_rp::flash::WRITE_SIZE]);
    let mut updater = FirmwareUpdater::new(config, &mut aligned.0);

    let mut receiver = Receiver::new(header);
    let mut chunk = [0u8; WRITE_CHUNK];
    let mut offset: usize = 0;
    while !receiver.is_complete() {
        // チャンクを「残量か 4KB の小さい方」まで読み溜めてから書く（書き込み回数を抑える）。
        let want = (receiver.remaining() as usize).min(WRITE_CHUNK);
        read_exact(socket, &mut chunk[..want]).await?;
        receiver.accept(&chunk[..want]).map_err(OtaFail::Protocol)?;
        // 端数は 0xFF（消去後のフラッシュと同値）で埋めて書き込み単位に丸める。
        chunk[want..].fill(0xFF);
        let padded = want.next_multiple_of(embassy_rp::flash::WRITE_SIZE);
        updater
            .write_firmware(offset, &chunk[..padded])
            .await
            .map_err(|_| OtaFail::Flash)?;
        offset += want;
    }
    receiver.verify().map_err(OtaFail::Protocol)?;
    updater.mark_updated().await.map_err(|_| OtaFail::Flash)?;
    Ok(header.len)
}

/// buf を埋め切るまで読む。EOF・タイムアウトは Socket エラー。
async fn read_exact(socket: &mut TcpSocket<'_>, buf: &mut [u8]) -> Result<(), OtaFail> {
    let mut filled = 0;
    while filled < buf.len() {
        match socket.read(&mut buf[filled..]).await {
            Ok(0) => return Err(OtaFail::Socket), // EOF
            Ok(n) => filled += n,
            Err(_) => return Err(OtaFail::Socket),
        }
    }
    Ok(())
}
```

注意点:
- `embassy_rp::flash::WRITE_SIZE` が存在しない場合（版によって定数名が違う）、`embassy_rp::flash::PAGE_SIZE`（=256）を使う。`AlignedBuffer` のサイズは STATE 書き込み単位で、embassy の examples/boot/application/rp の例に合わせるのが正。
- `socket.write_all` が無い場合は `embedded_io_async::Write` トレイトの import（`use embedded_io_async::Write as _;`）が要る。既存依存に `embedded-hal-async` はあるが `embedded-io-async` が必要なら Cargo.toml に `embedded-io-async = "0.6"` を追加する。
- `write_firmware` の消去はセクタ境界（4KB）ごとに行われる。チャンクを常に 4KB 揃えで送っているのはこのため（最終チャンクのみ端数可）。

- [ ] **Step 3: main.rs に watchdog・mark_booted・spawn を配線**

`crates/mube-firmware/src/main.rs` の変更点（該当箇所に挿入）:

冒頭の mod / use に追加:

```rust
mod ota;

use embassy_rp::flash::{Async as FlashAsync, Flash};
use embassy_rp::peripherals::FLASH;
use embassy_rp::watchdog::Watchdog;
use embassy_sync::blocking_mutex::raw::NoopRawMutex;
use embassy_sync::mutex::Mutex as AsyncMutex;
use embassy_boot_rp::{AlignedBuffer, FirmwareUpdater, FirmwareUpdaterConfig};
```

静的の近く（`SERVO_CMD` の前あたり）に追加:

```rust
/// QSPI フラッシュ全長。embassy-rp の Flash 型パラメータに使う。
pub(crate) const FLASH_SIZE: usize = 2 * 1024 * 1024;

/// OTA が使う共有フラッシュハンドル（DFU/STATE パーティションへの書き込み口）。
/// async Mutex なのはフラッシュ操作中に他タスクを待たせるため（XIP 停止を伴う）。
pub(crate) type OtaFlash =
    AsyncMutex<NoopRawMutex, Flash<'static, FLASH, FlashAsync, FLASH_SIZE>>;
static FLASH_CELL: StaticCell<OtaFlash> = StaticCell::new();
```

`main()` の先頭、`let p = embassy_rp::init(...)` の直後に追加:

```rust
    // ロールバック実機試験用の意図的な起動失敗（docs/firmware.md の OTA 節参照）。
    // watchdog リセット → ブートローダーの revert で旧ファームに戻ることを確認する。
    #[cfg(feature = "ota-rollback-test")]
    panic!("ota-rollback-test: intentional boot failure");

    // watchdog はブートローダーが張った 8 秒を引き継ぐ。ヘルス条件（WiFi + HTTP +
    // サーボ初期化）到達までは main が要所で直接餌をやり、以後は専任タスクが担う。
    // ヘルス到達前に panic / ハングすると 8 秒でリセットされ、ブートローダーが
    // 旧ファームへ revert する（これが OTA の自動ロールバック経路）。
    let mut watchdog = Watchdog::new(p.WATCHDOG);
    watchdog.start(Duration::from_secs(8));
```

WiFi join ループへ餌やりを追加（ループ本体の先頭に 1 行）:

```rust
    loop {
        watchdog.feed(); // 再試行が続いても watchdog で落ちないように
        match control
            .join(WIFI_SSID, cyw43::JoinOptions::new(WIFI_PASSWORD.as_bytes()))
            .await
        {
```

DHCP 待ちを餌やり付きへ変更（既存の `stack.wait_config_up().await;` を置換）:

```rust
    // DHCP 待ち: 4 秒ごとに餌をやりながら待つ（ルーター側の遅延で落ちないように）。
    while with_timeout(Duration::from_secs(4), stack.wait_config_up())
        .await
        .is_err()
    {
        watchdog.feed();
    }
```

`main()` 末尾、http_worker の spawn ループの**後**に追加:

```rust
    // ここまで到達 = ヘルス条件成立（サーボ・ボタン・WiFi・HTTP すべて起動済み）。
    // 更新を確定し（未確定のままだと次回リセットで revert される）、watchdog を専任タスクへ、
    // OTA 受信口を開く。
    let flash = FLASH_CELL.init(AsyncMutex::new(Flash::new(p.FLASH, p.DMA_CH1)));
    {
        let config = FirmwareUpdaterConfig::from_linkerfile(flash, flash);
        let mut aligned = AlignedBuffer([0; embassy_rp::flash::WRITE_SIZE]);
        let mut updater = FirmwareUpdater::new(config, &mut aligned.0);
        if let Err(e) = updater.mark_booted().await {
            // 確定に失敗すると次回リセットで revert されうる。ログだけ出して動作は継続する
            //（施解錠は生きているほうが鍵として安全側）。
            warn!("ota: mark_booted failed: {:?}", defmt::Debug2Format(&e));
        } else {
            info!("ota: mark_booted ok (this firmware is now confirmed)");
        }
    }
    spawner.spawn(watchdog_task(watchdog).unwrap());
    spawner.spawn(ota::ota_task(stack, flash).unwrap());
```

タスク定義を追加（auto_lock_task の近く）:

```rust
/// ヘルス条件到達後の watchdog 餌やり専任タスク。以後どんなハングでも 8 秒で自動再起動する
/// （鍵の可用性優先。挙動変更として docs/firmware.md に明記済み）。
#[embassy_executor::task]
async fn watchdog_task(mut watchdog: Watchdog) -> ! {
    loop {
        watchdog.feed();
        Timer::after(Duration::from_secs(2)).await;
    }
}
```

- [ ] **Step 4: ビルド + host テスト**

Run: `nix develop -c just firmware`
Expected: 成功

Run: `nix develop -c cargo host-test`
Expected: PASS

Run: `nix develop -c bash -c 'cargo build -p mube-firmware --features ota-rollback-test 2>&1 | tail -3'`
Expected: 成功（試験用ビルドもコンパイルできること）

- [ ] **Step 5: コミット**

```bash
git add crates/mube-firmware
git commit -m "firmware: OTA 受信タスク（TCP 4242 → DFU）と watchdog ロールバック配線"
```

---

### Task 5: lockctl `ota` サブコマンドと `just ota`

**Files:**
- Modify: `scripts/lockctl.ts`
- Test: `scripts/lockctl.test.ts`（既存ファイルに追記）
- Modify: `Justfile`（`ota` レシピ追加）
- Modify: `flake.nix`（devShell に `pkgs.cargo-binutils` 追加）

**Interfaces:**
- Consumes: Task 4 の TCP 4242 プロトコル、Task 2 の `/api/version`
- Produces: `bun scripts/lockctl.ts ota <bin>` / `just ota`

- [ ] **Step 1: 失敗するテストを書く**

`scripts/lockctl.test.ts` に追記:

```ts
import { crc32, buildOtaHeader, parseOtaReply } from "./lockctl";

describe("ota", () => {
  test("crc32 known vector", () => {
    // IEEE CRC32 の標準テストベクタ（mube-core 側のテストと同一）
    expect(crc32(new TextEncoder().encode("123456789"))).toBe(0xcbf43926);
  });

  test("crc32 empty is zero", () => {
    expect(crc32(new Uint8Array(0))).toBe(0);
  });

  test("buildOtaHeader layout", () => {
    const h = buildOtaHeader(0x0102, 0xdeadbeef);
    expect(h.length).toBe(16);
    expect(new TextDecoder().decode(h.slice(0, 8))).toBe("MUBEOTA1");
    // length u32 LE
    expect([...h.slice(8, 12)]).toEqual([0x02, 0x01, 0x00, 0x00]);
    // crc32 u32 LE
    expect([...h.slice(12, 16)]).toEqual([0xef, 0xbe, 0xad, 0xde]);
  });

  test("parseOtaReply", () => {
    expect(parseOtaReply("OK 12345\n")).toEqual({ ok: true, detail: "12345" });
    expect(parseOtaReply("ERR crc mismatch\n")).toEqual({ ok: false, detail: "crc mismatch" });
    expect(parseOtaReply("garbage")).toBeNull();
  });
});
```

（既存テストの import 形式・describe の使い方はファイル内の既存記述に合わせること）

- [ ] **Step 2: テストが落ちることを確認**

Run: `nix develop -c bun test scripts/`
Expected: FAIL（crc32 等が未定義）

- [ ] **Step 3: lockctl.ts に実装を足す**

`scripts/lockctl.ts` へ追加（既存の export 関数群の後ろ）:

```ts
// ---- OTA（ファーム更新）----
// ワイヤ形式は crates/mube-core/src/ota.rs と同一契約:
//   "MUBEOTA1" + length u32 LE + crc32 u32 LE + ペイロード → "OK <len>\n" | "ERR <reason>\n"

/** IEEE CRC32（reflected, poly 0xEDB88320）。テーブル版（1MB 級の入力があるため）。 */
export function crc32(data: Uint8Array): number {
  const table = crc32Table();
  let c = 0xffffffff;
  for (let i = 0; i < data.length; i++) {
    c = (c >>> 8) ^ table[(c ^ data[i]) & 0xff];
  }
  return (c ^ 0xffffffff) >>> 0;
}

let CRC_TABLE: Uint32Array | null = null;
function crc32Table(): Uint32Array {
  if (CRC_TABLE) return CRC_TABLE;
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  CRC_TABLE = t;
  return t;
}

/** OTA フレームの 16 バイトヘッダを組み立てる。 */
export function buildOtaHeader(len: number, crc: number): Uint8Array {
  const buf = new Uint8Array(16);
  buf.set(new TextEncoder().encode("MUBEOTA1"), 0);
  const view = new DataView(buf.buffer);
  view.setUint32(8, len, true);
  view.setUint32(12, crc >>> 0, true);
  return buf;
}

/** 応答行を解釈する。想定外は null。 */
export function parseOtaReply(line: string): { ok: boolean; detail: string } | null {
  const m = line.trim().match(/^(OK|ERR) (.+)$/);
  if (!m) return null;
  return { ok: m[1] === "OK", detail: m[2] };
}

/** TCP でイメージを送り、応答行を受ける。 */
async function sendImage(host: string, port: number, image: Uint8Array): Promise<string> {
  const header = buildOtaHeader(image.length, crc32(image));
  return await new Promise<string>((resolve, reject) => {
    let reply = "";
    Bun.connect({
      hostname: host,
      port,
      socket: {
        open(socket) {
          socket.write(header);
          socket.write(image); // Bun が内部バッファリングし drain で送り切る
          socket.flush();
        },
        data(socket, data) {
          reply += new TextDecoder().decode(data);
          if (reply.includes("\n")) {
            socket.end();
            resolve(reply);
          }
        },
        close() {
          if (!reply.includes("\n")) reject(new Error("応答なしで切断された"));
        },
        error(_socket, err) {
          reject(err);
        },
        connectError(_socket, err) {
          reject(err);
        },
      },
    });
  });
}

/** /api/version を叩く。未対応ファーム・接続不可は null。 */
async function fetchVersion(base: string): Promise<string | null> {
  try {
    const resp = await fetch(`${base}/api/version`, { signal: AbortSignal.timeout(3000) });
    if (!resp.ok) return null;
    return (await resp.json())?.version ?? null;
  } catch {
    return null;
  }
}

/** OTA 一式: 事前チェック → 送信 → 再起動後のバージョン確認。進捗は console に出す。 */
export async function runOta(binPath: string, host: string, httpBase: string): Promise<void> {
  const image = new Uint8Array(await Bun.file(binPath).arrayBuffer());
  if (image.length === 0) throw new Error(`${binPath} が空`);
  console.log(`image: ${binPath} (${(image.length / 1024).toFixed(0)} KB)`);

  // 解錠中の更新は再起動で状態表示が実態とずれる（起動時は LOCKED 扱い）ため既定で拒否。
  const state = await fetch(`${httpBase}/api/status`, { signal: AbortSignal.timeout(5000) })
    .then((r) => r.text())
    .then(parseState)
    .catch(() => null);
  if (state === null) throw new Error(`${httpBase} に接続できない。IP・電源・WiFi 接続を確認してね`);
  if (state === "UNLOCKED" && process.env.OTA_ALLOW_UNLOCKED !== "1") {
    throw new Error("解錠中。施錠してから実行するか OTA_ALLOW_UNLOCKED=1 を付けて");
  }

  const before = await fetchVersion(httpBase);
  console.log(`current version: ${before ?? "(不明: /api/version 未対応ファーム)"}`);

  const otaPort = Number(process.env.OTA_PORT ?? "4242");
  const reply = parseOtaReply(await sendImage(host, otaPort, image));
  if (reply === null) throw new Error("応答が想定外");
  if (!reply.ok) throw new Error(`デバイス側エラー: ${reply.detail}`);
  console.log(`送信完了 (${reply.detail} bytes)。再起動とスワップを待つ（数十秒かかる）...`);

  // スワップは ACTIVE/DFU の消去を伴い数十秒かかる。3 分までポーリングする。
  const deadline = Date.now() + 180_000;
  while (Date.now() < deadline) {
    await new Promise((r) => setTimeout(r, 3000));
    const now = await fetchVersion(httpBase);
    if (now !== null && now !== before) {
      console.log(`更新完了: ${before ?? "?"} → ${now}`);
      return;
    }
  }
  throw new Error(
    "3 分待ってもバージョンが変わらない。旧版のまま応答するなら revert された可能性。probe-rs でログ確認を",
  );
}
```

`if (import.meta.main)` ブロックのサブコマンド分岐に `ota` を追加（usage 文字列にも追記）:

```ts
  if (cmd === "ota") {
    const binPath = process.argv[3];
    if (!binPath) {
      console.error("usage: bun scripts/lockctl.ts ota <path/to/firmware.bin>");
      process.exit(2);
    }
    // host/base の解決は既存コードと同じ（TARGET_IP 必須・PORT 既定 80）
    try {
      await runOta(binPath, host, base);
    } catch (err) {
      console.error(`error: ${err instanceof Error ? err.message : err}`);
      process.exit(1);
    }
    process.exit(0);
  }
```

（既存の `cmd !== "toggle" && ...` の判定より**前**に置くか、判定に `"ota"` を加える。既存の host/base 解決コードの位置関係に合わせて整える）

- [ ] **Step 4: テストが通ることを確認**

Run: `nix develop -c bun test scripts/`
Expected: PASS（既存の lockctl/fetch-cyw43 テスト含め全緑）

- [ ] **Step 5: flake.nix と Justfile**

`flake.nix` の devShell packages、rust toolchain の行の直後に追加:

```nix
            pkgs.cargo-binutils  # rust-objcopy（OTA 用 raw バイナリの切り出し。llvm-tools は rust-toolchain.toml 側）
```

`Justfile` に追加（firmware レシピの近く）:

```
# OTA でファームを更新（ビルド → raw バイナリ化 → TCP 4242 で送信。要 TARGET_IP と書き込み済みブートローダー）
ota: blobs webui
    cargo build --release
    rust-objcopy -O binary --remove-section .boot2 target/thumbv6m-none-eabi/release/mube-firmware target/mube-firmware-ota.bin
    bun scripts/lockctl.ts ota target/mube-firmware-ota.bin
```

- [ ] **Step 6: objcopy の出力を検証**

Run: `nix develop -c bash -c 'cargo build --release && rust-objcopy -O binary --remove-section .boot2 target/thumbv6m-none-eabi/release/mube-firmware /tmp/ota-test.bin && ls -l /tmp/ota-test.bin'`
Expected: 成功し、サイズが ELF のフラッシュ搭載分（~532KB 前後）と同程度。**2MB 級や 32KB 底上げになっていたら boot2 の除去に失敗している**（その場合 `readelf -l` で LOAD セグメントを確認し、`--only-section` 方式に切り替える）

- [ ] **Step 7: コミット**

```bash
git add scripts/lockctl.ts scripts/lockctl.test.ts Justfile flake.nix
git commit -m "lockctl/just: ota サブコマンド追加（CRC32 付き TCP 送信 + バージョン確認）"
```

---

### Task 6: ドキュメントと後片付け

**Files:**
- Modify: `docs/firmware.md`（OTA 節の新設・書き込み節の更新）
- Modify: `README.md`（コマンド表に `just ota`）
- Modify: `CLAUDE.md`（コマンド表に 1 行）
- Modify: backlog タスク 15（notes 更新）

- [ ] **Step 1: docs/firmware.md に OTA 節を書く**

「書き込みと実行」節を更新し、末尾近くに「OTA アップデート」節を新設する。内容（この構成で書く。文体は既存 docs に合わせる）:

1. **初回プロビジョニング**: フラッシュレイアウト図（spec の表を転記）、DAP での 2 段書き込み:

```
cargo build --release                       # mube-boot と mube-firmware
probe-rs download --chip RP2040 target/thumbv6m-none-eabi/release/mube-boot
probe-rs download --chip RP2040 target/thumbv6m-none-eabi/release/mube-firmware
probe-rs reset --chip RP2040
```

   `cargo run --release` での開発フロー（defmt ログ）はブートローダーが焼けていれば従来どおり使えることも書く。
2. **日常の更新**: `just ota`（要 TARGET_IP。ビルド → objcopy → TCP 4242 送信 → /api/version で反映確認。スワップで再起動に数十秒かかる）。解錠中は既定で拒否・`OTA_ALLOW_UNLOCKED=1` で上書きできること。
3. **ロールバックの仕組み**: mark_booted 前に watchdog（8 秒）が発火すると旧ファームへ revert。watchdog は以後も常時有効（ハング時 8 秒で自動再起動、という挙動変更を明記）。
4. **実機テスト手順**（お兄ちゃん向けチェックリスト）:
   - 正常系: 適当なコミットで `just ota` → `/api/version` が新しい git describe になる
   - 電源断: 転送中に AC を抜く → 再起動後も旧版で施解錠できる
   - ロールバック: `cargo build --release -p mube-firmware --features ota-rollback-test` で壊れ玉を作り、`rust-objcopy ... && bun scripts/lockctl.ts ota ...` で送る → 8 秒 ×（swap + revert）後に旧版で復帰していること
5. **セキュリティ注意**: 既存の「平文 HTTP・無認証」節に OTA ポートも同じ信頼モデル（LAN 内のみ）である旨を追記。

- [ ] **Step 2: README.md と CLAUDE.md のコマンド表**

README.md のコマンド表（あれば firmware 系の並び）と CLAUDE.md の表に追加:

```markdown
| OTA でファーム更新（LAN 内） | `just ota` | — |
```

- [ ] **Step 3: backlog タスクへ進捗を記録**

```bash
nix develop -c backlog task edit 15 --notes "実装済み（mube-boot / mube-core ota / firmware ota タスク / lockctl ota / just ota / docs）。残: 実機での初回プロビジョニングと 3 種の実機テスト（docs/firmware.md の OTA 節参照）。完了条件のうち実機系 AC はそこで消化する"
```

タスクのステータスは To Do のまま（実機検証が済むまで Done にしない）。

- [ ] **Step 4: 最終確認 + コミット**

Run: `nix develop -c cargo host-test` / `nix develop -c bun test scripts/` / `nix develop -c just firmware`
Expected: すべて成功

```bash
git add docs/firmware.md README.md CLAUDE.md backlog/
git commit -m "docs: OTA 手順（初回プロビジョニング・just ota・ロールバック試験）を追記"
```

---

## 実機検証（プラン外・お兄ちゃんの手作業）

このプランの完了 = 「ビルド・テスト・ドキュメントが揃い、実機検証待ち」の状態。
実機での初回プロビジョニングと 3 種のテスト（正常系・電源断・ロールバック）は
docs/firmware.md の手順に従って行い、済んだら `backlog task edit 15 -s Done`。
