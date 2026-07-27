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
use embedded_io_async::Write as _;
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
                let _ = writeln!(line, "OK {}", len);
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
                let _ = writeln!(line, "ERR {}", fail.reason());
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
