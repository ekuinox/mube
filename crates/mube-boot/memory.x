/* mube の OTA フラッシュレイアウト（2MB QSPI）。
   spec: docs/superpowers/specs/2026-07-26-firmware-ota-embassy-boot-design.md
   embassy-boot の from_linkerfile が末尾のシンボル群を読む。
   アプリ側 crates/mube-firmware/memory.x と数値を必ず一致させること。 */
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
