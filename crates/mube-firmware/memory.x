/* RP2040 (Pico W) の OTA レイアウト。アプリは ACTIVE スロットから XIP 実行される。
   ブートローダー（crates/mube-boot）を先に焼いておくこと（焼き方は docs/firmware.md）。
   レイアウトの単一ソースは crates/mube-boot/memory.x。数値を必ず一致させる。
   BOOT2 領域は link-rp.x が .boot2 出力セクションの配置先として参照するため定義だけ残すが、
   embassy-rp の boot2-none feature により中身は空（アプリ ELF はセクタ 0 に触れない。
   boot2 とブートローダー先頭は同じ 4KB 消去セクタに同居するため、アプリに boot2 を
   持たせると probe-rs のセクタ消去がブートローダーを壊しうる）。 */
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
