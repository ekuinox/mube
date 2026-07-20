//! mube スマートロックのブラウザ WebUI（yew/WASM）。
//! 同一オリジンの JSON API を叩く：GET /api/status, POST /api/lock|unlock。
//! レスポンスは {"state":"LOCKED"|"UNLOCKED"}。

use std::str::FromStr;

use gloo_net::http::Request;
use wasm_bindgen_futures::spawn_local;
use yew::prelude::*;

#[derive(Clone, Copy, PartialEq)]
enum State {
    Locked,
    Unlocked,
    Unknown,
}

impl FromStr for State {
    type Err = ();

    /// `{"state":"LOCKED"|"UNLOCKED"}` から状態を判定する。
    /// UNLOCKED は LOCKED を含むので、先に UNLOCKED を判定する。想定外は Err。
    fn from_str(body: &str) -> Result<Self, Self::Err> {
        if body.contains("UNLOCKED") {
            Ok(State::Unlocked)
        } else if body.contains("LOCKED") {
            Ok(State::Locked)
        } else {
            Err(())
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
