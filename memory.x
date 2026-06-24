/* RP2040 (Raspberry Pi Pico W) のメモリレイアウト。
   先頭 0x100 は第2段ブートローダ (.boot2)。残り 2MB が QSPI フラッシュ。
   .boot2 セクションの配置と SRAM の詳細は embassy-rp の link-rp.x が補う。 */
MEMORY {
    BOOT2 : ORIGIN = 0x10000000, LENGTH = 0x100
    FLASH : ORIGIN = 0x10000100, LENGTH = 2048K - 0x100
    RAM   : ORIGIN = 0x20000000, LENGTH = 256K
}
