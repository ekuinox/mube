//! picoserve による HTTP ルータ。Task 5 で埋め込み SPA アセットと JSON API を配信する。
//! 本ファイルは互換スパイク（Task 4）の最小スケルトン。ハンドラは Task 5 で
//! firmware の共有状態（LOCK_STATE / apply_target）を直接叩く形へ差し替える。
//!
//! === 確定 picoserve API（版 0.19.0 / features = ["embassy"] / embassy-net 0.9 単一解決）===
//! Task 5 実装者への引き継ぎ。上流 API は下記の形（`cargo tree -i embassy-net` で
//! embassy-net v0.9.1 単一。picoserve 0.19.0 が同じ 0.9 系を共有するため TcpSocket 型は一致）。
//!
//! (a) Router 構築・ルート登録:
//!     use picoserve::routing::get;   // get/post/put/delete/... は picoserve_derive 生成
//!     picoserve::Router::new()
//!         .route("/", get(|| async { "ok" }))          // 2021 edition 形。async || も可
//!         .route("/api/x", get(handler).post(handler))  // MethodRouter に .post 等を連結
//!     // 戻り値: picoserve::Router<impl picoserve::routing::PathRouter>
//!
//! (b) バイト列＋Content-Type レスポンス:
//!     use picoserve::response::Response;
//!     // ハンドラ戻り値が IntoResponse であればよい。素の &str は "text/plain; charset=utf-8"、
//!     // 素の &[u8] は "application/octet-stream" が自動付与される（Content トレイト実装）。
//!     // Content-Type を任意指定したい場合（SPA の text/html, application/json 等）:
//!     Response::ok(body_bytes /* &[u8] または &str */)
//!         .with_header("Content-Type", "text/html; charset=utf-8")
//!     // Response::new(StatusCode, content) / Response::ok(content) / Response::empty(status)
//!     // .with_header(name: &'static str, value: impl Display) / .with_status_code(...)
//!
//! (c) listen/serve ループ（ポート 80 / 複数ワーカーソケット）:
//!     use picoserve::{Config, Timeouts, Server};
//!     let app = http::make_app();
//!     let config = Config::new(Timeouts { /* start/read/write: Option<Duration> */ })
//!         .keep_connection_alive();   // 複数ソケット時のみ推奨（単一だと1クライアント占有）
//!     // ワーカーごとに #[embassy_executor::task(pool_size = N)] を用意し、各タスクで:
//!     let mut http_buffer = [0u8; 2048];
//!     let mut rx = [0u8; 1024];
//!     let mut tx = [0u8; 1024];
//!     Server::new(&app, &config, &mut http_buffer)
//!         .listen_and_serve(task_id, stack, /*port*/ 80u16, &mut rx, &mut tx)
//!         .await;
//!     // listen_and_serve(self, task_id: impl LogDisplay, stack: embassy_net::Stack,
//!     //                  port: u16, tcp_rx_buffer: &mut [u8], tcp_tx_buffer: &mut [u8])
//!     // は1接続ずつ処理する無限ループ。N 並列にするには同タスクを pool_size=N で spawn する。

use picoserve::routing::get;

/// スパイク用の最小ルータ（Task 5 で本実装に差し替え）。
pub fn make_app() -> picoserve::Router<impl picoserve::routing::PathRouter> {
    picoserve::Router::new().route("/", get(|| async { "ok" }))
}
