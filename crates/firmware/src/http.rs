//! picoserve による HTTP ルータ。埋め込み SPA アセットと JSON API を port 80 で配信する。
//!
//! === 確定 picoserve API（版 0.19.0 / features = ["embassy"]）===
//! Task 4 引き継ぎを実装時に検証した結果、下記へ更新した:
//!  - `Timeouts` のフィールドは `Option<Duration>` ではなく素の `Duration`。
//!    フィールドは `start_read_request` / `persistent_start_read_request`
//!    / `read_request` / `write`（Task 4 メモの 3 フィールド・Option は誤り）。
//!  - `Config` は `pub timeouts` / `pub connection`。`Config::new(Timeouts)` で生成し、
//!    複数ソケット運用では `.keep_connection_alive()` を付ける。
//!  - レスポンスの Content-Type は `Content` トレイトの `content_type()` から
//!    自動付与される（`&[u8]` は application/octet-stream、`&str` は text/plain）。
//!    そのため `Response::ok(bytes).with_header("Content-Type", ..)` は Content-Type を
//!    二重に吐く。ここでは独自の `Content` 実装 `StaticAsset` で正しい単一の
//!    Content-Type を持たせる（`Response::ok(StaticAsset{ .. })`）。
//!  - listen ループは `Server::new(&app, &config, &mut http_buf)
//!      .listen_and_serve(task_id, stack, port, &mut rx, &mut tx).await`。
//!    `Server::new` は shutdown_signal = pending() で構築されるため、そのまま無限 listen。
//!    1 タスク 1 接続なので、並列化は同タスクを `#[embassy_executor::task(pool_size=N)]`
//!    で N 本 spawn する（main.rs 側で配線）。

use mube_core::{state_json, target_for, Action, LockState};
use picoserve::response::{Content, Response};
use picoserve::routing::{get, post};

// yew/trunk の出力を埋め込む（build.rs が存在を保証）。`&'static [u8]` はフラッシュに
// 置かれ、picoserve がそこから直接ソケットへ流すため RAM に丸ごとは載らない。
const INDEX_HTML: &[u8] = include_bytes!("../../webui/dist/index.html");
const WEBUI_JS: &[u8] = include_bytes!("../../webui/dist/webui.js");
const WEBUI_WASM: &[u8] = include_bytes!("../../webui/dist/webui_bg.wasm");

const CT_HTML: &str = "text/html; charset=utf-8";
const CT_JS: &str = "application/javascript";
const CT_WASM: &str = "application/wasm";
const CT_JSON: &str = "application/json";

/// 静的バイト列＋任意の Content-Type を返す `Content` 実装。
/// これにより Content-Type が正しく単一で付く（`with_header` の二重付与を避ける）。
struct StaticAsset {
    body: &'static [u8],
    content_type: &'static str,
}

impl Content for StaticAsset {
    fn content_type(&self) -> &'static str {
        self.content_type
    }

    fn content_length(&self) -> usize {
        self.body.len()
    }

    async fn write_content<W: picoserve::io::Write>(self, writer: W) -> Result<(), W::Error> {
        self.body.write_content(writer).await
    }
}

/// バイト列＋Content-Type で 200 OK を返す。
fn asset(body: &'static [u8], content_type: &'static str) -> Response<impl picoserve::response::HeadersIter, impl picoserve::response::Body> {
    Response::ok(StaticAsset { body, content_type })
}

/// `&'static str` の JSON を application/json で 200 OK にして返す。
fn json(body: &'static str) -> Response<impl picoserve::response::HeadersIter, impl picoserve::response::Body> {
    asset(body.as_bytes(), CT_JSON)
}

// 共有状態への口。実体は main.rs（LOCK_STATE 参照・apply_target）。
fn current() -> LockState {
    crate::current_state()
}

/// 操作を適用し、結果状態の JSON を返す。Status など駆動不要な操作は現在状態を返す。
/// 注: Toggle の read-modify-write は非アトミック。HTTP_WORKERS 並列下で同時 toggle が
/// 来ると片方が失われうる（last-writer-wins）。物理ボタンと同じく LAN 単一利用前提で許容する。
fn drive(action: Action) -> &'static str {
    let cur = current();
    if let Some(target) = target_for(action, cur) {
        crate::apply_target(target);
        state_json(target)
    } else {
        state_json(cur)
    }
}

/// ルータを構築する。埋め込みアセット配信と JSON API を登録する。
pub fn make_app() -> picoserve::Router<impl picoserve::routing::PathRouter> {
    picoserve::Router::new()
        .route("/", get(|| async { asset(INDEX_HTML, CT_HTML) }))
        .route("/webui.js", get(|| async { asset(WEBUI_JS, CT_JS) }))
        .route("/webui_bg.wasm", get(|| async { asset(WEBUI_WASM, CT_WASM) }))
        .route("/api/status", get(|| async { json(state_json(current())) }))
        .route("/api/lock", post(|| async { json(drive(Action::Lock)) }))
        .route("/api/unlock", post(|| async { json(drive(Action::Unlock)) }))
        .route("/api/toggle", post(|| async { json(drive(Action::Toggle)) }))
}
