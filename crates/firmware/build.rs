//! メモリレイアウトをリンカに渡し、cortex-m-rt / embassy-rp / defmt のリンカスクリプトを束ねる。
//! embassy の examples/rp/build.rs と同等の内容。

use std::env;
use std::fs::File;
use std::io::Write;
use std::path::PathBuf;

fn main() {
    // memory.x を OUT_DIR にコピーしてリンカの検索パスに入れる。
    let out = &PathBuf::from(env::var_os("OUT_DIR").unwrap());
    File::create(out.join("memory.x"))
        .unwrap()
        .write_all(include_bytes!("memory.x"))
        .unwrap();
    println!("cargo:rustc-link-search={}", out.display());
    println!("cargo:rerun-if-changed=memory.x");
    println!("cargo:rerun-if-changed=build.rs");

    // リンカ引数。--nmagic はアライメント由来のフラッシュ肥大化を防ぐ。
    println!("cargo:rustc-link-arg-bins=--nmagic");
    println!("cargo:rustc-link-arg-bins=-Tlink.x"); // cortex-m-rt
    println!("cargo:rustc-link-arg-bins=-Tlink-rp.x"); // embassy-rp (boot2 等)
    println!("cargo:rustc-link-arg-bins=-Tdefmt.x"); // defmt

    // WebUI の埋め込みアセット（yew/trunk 出力）が無ければ、束ねビルド未実行として明示的に失敗させる。
    // http.rs が include_bytes! で埋め込むため、無いと分かりにくいコンパイルエラーになる。ここで先に落とす。
    let dist = std::path::Path::new("../webui/dist");
    for f in ["index.html", "webui.js", "webui_bg.wasm"] {
        if !dist.join(f).exists() {
            panic!(
                "crates/webui/dist/{f} が無い。先に `cd crates/webui && trunk build --release` を実行してから firmware をビルドすること。"
            );
        }
    }
    println!("cargo:rerun-if-changed=../webui/dist/index.html");
    println!("cargo:rerun-if-changed=../webui/dist/webui.js");
    println!("cargo:rerun-if-changed=../webui/dist/webui_bg.wasm");
}
