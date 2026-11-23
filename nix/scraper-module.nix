{ self }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.parkrun-scraper;

  scrape = pkgs.writeShellScript "parkrun-scrape" ''
    set -euo pipefail
    export PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.sqlite ]}
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    ${lib.getExe cfg.tool} ${lib.escapeShellArg cfg.athlete} "$tmp/parkruns.db"
    [ "$(sqlite3 "$tmp/parkruns.db" 'select count(*) from runs')" -gt 0 ]
    # Renamed into place: readers may hold the old file open, and writing in
    # place would show them a torn one.
    install -Dm644 "$tmp/parkruns.db" ${lib.escapeShellArg "${cfg.publish}.new"}
    mv -f ${lib.escapeShellArg "${cfg.publish}.new"} ${lib.escapeShellArg cfg.publish}
  '';
in
{
  options.services.parkrun-scraper = {
    enable = lib.mkEnableOption "the parkrun scraper";

    tool = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.parkrun-to-sqlite;
      defaultText = lib.literalExpression "parkrun.packages.\${system}.parkrun-to-sqlite";
      description = "The CLI that builds the database: `<tool> <athlete> <db>`.";
    };

    athlete = lib.mkOption {
      type = lib.types.str;
      default = "3173185";
      description = "parkrun athlete id.";
    };

    publish = lib.mkOption {
      type = lib.types.str;
      example = "/var/lib/dbs/parkrun/parkruns.db";
      description = "Where the database is installed. Its directory must exist and be writable by `user`.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "james";
      description = "User the scrape runs as.";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "Sat *-*-* 13:59:00";
      description = "systemd OnCalendar expression.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.parkrun-scraper = {
      description = "Scrape parkrun results into parkruns.db";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        ExecStart = scrape;
        TimeoutStartSec = "30min";
        Nice = 19;
        NoNewPrivileges = true;
        PrivateTmp = true;
      };
    };

    systemd.timers.parkrun-scraper = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.interval;
        Persistent = true;
        Unit = "parkrun-scraper.service";
      };
    };
  };
}
