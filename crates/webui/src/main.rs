//! mube スマートロックのブラウザ WebUI（yew/WASM）。
//! 同一オリジンの JSON API を叩く：GET /api/status, POST /api/lock|unlock。
//! レスポンスは {"state":"LOCKED"|"UNLOCKED"}。

use std::str::FromStr;

use gloo_net::http::Request;
use serde::Deserialize;
use wasm_bindgen_futures::spawn_local;
use yew::prelude::*;

#[derive(Clone, Copy, PartialEq)]
enum State {
    Locked,
    Unlocked,
    Unknown,
}

/// API レスポンス `{"state":"..."}` の形。JSON をパースして state を取り出す。
#[derive(Deserialize)]
struct StatusResponse<'a> {
    state: &'a str,
}

impl FromStr for State {
    type Err = ();

    /// API レスポンス（`{"state":"LOCKED"|"UNLOCKED"}`）を JSON としてパースし、
    /// state の値で判定する（空白等のフォーマット揺れには寛容、値は厳密）。想定外は Err。
    fn from_str(body: &str) -> Result<Self, Self::Err> {
        let (resp, _) = serde_json_core::from_str::<StatusResponse>(body).map_err(|_| ())?;
        match resp.state {
            "LOCKED" => Ok(State::Locked),
            "UNLOCKED" => Ok(State::Unlocked),
            _ => Err(()),
        }
    }
}

#[function_component(App)]
fn app() -> Html {
    let state = use_state(|| State::Unknown);

    // 初回マウントで現在状態を取得。
    {
        let state = state.clone();
        use_effect_with((), move |_| {
            let state = state.clone();
            spawn_local(async move {
                if let Ok(resp) = Request::get("/api/status").send().await {
                    if let Ok(text) = resp.text().await {
                        state.set(text.parse().unwrap_or(State::Unknown));
                    }
                }
            });
            || ()
        });
    }

    // POST してレスポンスの状態で更新するコールバックを作る。
    let post = {
        let state = state.clone();
        Callback::from(move |path: &'static str| {
            let state = state.clone();
            spawn_local(async move {
                if let Ok(resp) = Request::post(path).send().await {
                    if let Ok(text) = resp.text().await {
                        state.set(text.parse().unwrap_or(State::Unknown));
                    }
                }
            });
        })
    };

    let (label, color) = match *state {
        State::Locked => ("施錠 (LOCKED)", "#c0392b"),
        State::Unlocked => ("解錠 (UNLOCKED)", "#27ae60"),
        State::Unknown => ("― 取得中 ―", "#888"),
    };

    let on_lock = {
        let post = post.clone();
        Callback::from(move |_| post.emit("/api/lock"))
    };
    let on_unlock = {
        let post = post.clone();
        Callback::from(move |_| post.emit("/api/unlock"))
    };

    html! {
        <main style="font-family:sans-serif;max-width:20rem;margin:2rem auto;text-align:center">
            <h1>{ "mube smart lock" }</h1>
            <p style={format!("font-size:1.5rem;font-weight:bold;color:{color}")}>{ label }</p>
            <button style="font-size:1.2rem;padding:0.6rem 1.4rem;margin:0.3rem" onclick={on_lock}>{ "施錠" }</button>
            <button style="font-size:1.2rem;padding:0.6rem 1.4rem;margin:0.3rem" onclick={on_unlock}>{ "解錠" }</button>
        </main>
    }
}

fn main() {
    yew::Renderer::<App>::new().render();
}
