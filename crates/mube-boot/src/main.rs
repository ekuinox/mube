//! mube ブートローダー。embassy-boot-rp の A/B スワップをそのまま使う薄い殻。
//! swap/revert 中の電源断からも回復できるよう watchdog 付きフラッシュで動く。
//! ロジックは持たない（持つとブートローダー自身の更新が必要になる）。

#![no_std]
#![no_main]

use core::cell::RefCell;

use cortex_m_rt::entry;
use defmt_rtt as _;
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
