//! 接続設定。ビルド時に環境変数 `WIFI_SSID` / `WIFI_PASSWORD` から埋め込む。
//!
//!     WIFI_SSID=... WIFI_PASSWORD=... nix develop -c cargo build --release --locked
//!
//! 未設定のときはプレースホルダにフォールバックする（ビルドは通るが実機では
//! WiFi に接続できない）。実値をソースやコミットに書かないこと。
//! rustc は `option_env!` の参照を dep-info に記録するため、環境変数の値を
//! 変えれば再ビルドされる。

pub const WIFI_SSID: &str = match option_env!("WIFI_SSID") {
    Some(v) => v,
    None => "YOUR_WIFI_SSID",
};

pub const WIFI_PASSWORD: &str = match option_env!("WIFI_PASSWORD") {
    Some(v) => v,
    None => "YOUR_WIFI_PASSWORD",
};
