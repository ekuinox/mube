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
    let dist = std::path::Path::new("../mube-webui/dist");
    for f in ["index.html", "mube-webui.js", "mube-webui_bg.wasm"] {
        if !dist.join(f).exists() {
            panic!(
                "crates/mube-webui/dist/{f} が無い。先に `cd crates/mube-webui && trunk build --release` を実行してから firmware をビルドすること。"
            );
        }
    }
    println!("cargo:rerun-if-changed=../mube-webui/dist/index.html");
    println!("cargo:rerun-if-changed=../mube-webui/dist/mube-webui.js");
    println!("cargo:rerun-if-changed=../mube-webui/dist/mube-webui_bg.wasm");

    // 更新が反映されたかを /api/version で確認できるよう、git describe を埋め込む。
    // .git が無い環境（tarball 等）でもビルドできるよう "unknown" へフォールバック。
    let version = std::process::Command::new("git")
        .args(["describe", "--always", "--dirty"])
        .output()
        .ok()
        .filter(|o| o.status.success())
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .unwrap_or_else(|| "unknown".to_string());
    println!("cargo:rustc-env=MUBE_VERSION={version}");
    // HEAD の移動（コミット・ブランチ切替）で再実行し、バージョンの陳腐化を防ぐ。
    // linked worktree では .git がファイルのため、実体は rev-parse で解決する。
    if let Some(git_dir) = std::process::Command::new("git")
        .args(["rev-parse", "--absolute-git-dir"])
        .output()
        .ok()
        .filter(|o| o.status.success())
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
    {
        println!("cargo:rerun-if-changed={git_dir}/HEAD");
    }
}
