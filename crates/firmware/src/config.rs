//! 接続設定。実機投入前に実値へ書き換える。
//!
//! 注意: 実際の SSID / パスワードをそのままコミットしないこと。運用では
//!   - 本ファイルを `.gitignore` に追加して各自で管理する、または
//!   - `option_env!("WIFI_SSID")` などビルド時環境変数に切り替える
//!
//! のどちらかにする。ここでは雛形なのでプレースホルダを置いている。

pub const WIFI_SSID: &str = "YOUR_WIFI_SSID";
pub const WIFI_PASSWORD: &str = "YOUR_WIFI_PASSWORD";
