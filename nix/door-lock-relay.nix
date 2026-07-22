# door-lock 中継一式（Caddy ヘッダ削ぎプロキシ + cloudflared named tunnel）の
# home-manager モジュール。利用側は import して services.mube-door-lock.enable = true にするだけ。
# 前提: lingering 有効（loginctl enable-linger <user>）。
# 秘密物（~/.cloudflared/cert.pem とトンネル資格情報 <tunnel-id>.json）は含まない。手動配置。
{ config, lib, pkgs, ... }:
let
  cfg = config.services.mube-door-lock;

  # なぜサイトアドレスが「http://:<port>」+ default_bind なのか（Host 照合の罠）:
  # 「127.0.0.1:<port>」をサイトアドレスにすると Caddy はそれを Host 名として照合し、
  # cloudflared からのリクエスト（Host: door-lock-private.ekuinox.dev）にマッチせず
  # 空の 200 を返す（2026-07-22 に踏んだ）。Host 不問の「:<port>」で受け、
  # 待受アドレスの限定は default_bind 127.0.0.1 で行う。
  caddyfile = pkgs.writeText "door-lock-Caddyfile" ''
    {
    	default_bind 127.0.0.1
    	admin off
    	auto_https off
    	persist_config off
    }

    http://:${toString cfg.proxyPort} {
    	log {
    		output stderr
    		format json
    	}
    	# Pico の 2KB HTTP バッファに収まるよう、Access/ブラウザ由来の太いヘッダを削ぎ落とす
    	reverse_proxy ${cfg.picoOrigin} {
    		header_up -Cookie
    		header_up -Cf-*
    		header_up -Sec-*
    		header_up -User-Agent
    		header_up -Accept
    		header_up -Accept-Language
    		header_up -Accept-Encoding
    		header_up -Referer
    		header_up -Priority
    		header_up -Upgrade-Insecure-Requests
    		header_up -Cdn-Loop
    		header_up -X-Forwarded-*
    		header_up -X-Real-Ip
    	}
    }
  '';

  cloudflaredConfig = pkgs.writeText "door-lock-cloudflared.yml" ''
    tunnel: ${cfg.tunnelId}
    credentials-file: ${cfg.credentialsFile}
    protocol: ${cfg.protocol}
    ingress:
      - hostname: ${cfg.hostname}
        service: http://127.0.0.1:${toString cfg.proxyPort}
      - service: http_status:404
  '';
in
{
  options.services.mube-door-lock = {
    enable = lib.mkEnableOption "door-lock 中継（Caddy プロキシ + cloudflared）。lingering 必須（loginctl enable-linger）";

    hostname = lib.mkOption {
      type = lib.types.str;
      default = "door-lock-private.ekuinox.dev";
      description = "Cloudflare Tunnel の公開ホスト名";
    };

    tunnelId = lib.mkOption {
      type = lib.types.str;
      default = "b45a50d5-24f6-4732-9568-7971f9772504";
      description = "cloudflared named tunnel の ID";
    };

    picoOrigin = lib.mkOption {
      type = lib.types.str;
      default = "http://172.20.10.13:80";
      description = "転送先の Pico W オリジン";
    };

    proxyPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Caddy プロキシの待受ポート（127.0.0.1 のみ）";
    };

    protocol = lib.mkOption {
      type = lib.types.str;
      default = "http2";
      description = "cloudflared のトンネルプロトコル（この環境は QUIC が塞がれているため http2）";
    };

    credentialsFile = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.cloudflared/${cfg.tunnelId}.json";
      description = "トンネル資格情報 JSON のパス（手動配置。モジュールは配布しない）";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.door-lock-proxy = {
      Unit = {
        Description = "door-lock header-stripping proxy (Caddy)";
      };
      Service = {
        # ストアパスのファイル名が「Caddyfile」丸ごとではないため adapter の明示が必須
        ExecStart = "${pkgs.caddy}/bin/caddy run --config ${caddyfile} --adapter caddyfile";
        Restart = "always";
        RestartSec = 2;
      };
      Install.WantedBy = [ "default.target" ];
    };

    systemd.user.services.cloudflared-door-lock = {
      Unit = {
        Description = "door-lock Cloudflare named tunnel";
      };
      Service = {
        ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel --config ${cloudflaredConfig} run";
        Restart = "always";
        RestartSec = 2;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
