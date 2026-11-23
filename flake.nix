{
  description = "parkrun results scraper — parkrun.jamesst.one";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    inputs:
    let
      eachSystem = inputs.nixpkgs.lib.genAttrs (import inputs.systems);
      pkgsFor = eachSystem (system: inputs.nixpkgs.legacyPackages.${system});
    in
    {
      packages = eachSystem (system: {
        default = inputs.self.packages.${system}.parkrun-to-sqlite;
        parkrun-to-sqlite = pkgsFor.${system}.python3Packages.callPackage ./parkrun-to-sqlite.nix { };
      });

      nixosModules.scraper = import ./nix/scraper-module.nix { inherit (inputs) self; };

      checks = eachSystem (
        system:
        let
          pkgs = pkgsFor.${system};
        in
        {
          build = inputs.self.packages.${system}.default;
        }
        // pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          scraper = pkgs.testers.runNixOSTest {
            name = "parkrun-scraper";

            nodes.machine =
              { pkgs, ... }:
              {
                imports = [ inputs.self.nixosModules.scraper ];
                environment.systemPackages = [ pkgs.sqlite ];
                services.parkrun-scraper = {
                  enable = true;
                  user = "root";
                  publish = "/srv/site/parkruns.db";
                  tool = pkgs.writeShellScriptBin "parkrun-to-sqlite" ''
                    sqlite3 "$2" 'create table runs(event text)'
                    [ -e /srv/empty ] || sqlite3 "$2" "insert into runs values ('Albert Park for '||$1)"
                  '';
                };
                systemd.tmpfiles.rules = [ "d /srv/site 0755 root root -" ];
                systemd.timers.parkrun-scraper.wantedBy = pkgs.lib.mkForce [ ];
              };

            testScript = ''
              machine.wait_for_unit("multi-user.target")
              machine.succeed("systemctl start parkrun-scraper.service")
              assert machine.succeed("sqlite3 /srv/site/parkruns.db 'select event from runs'").strip() == "Albert Park for 3173185"

              machine.succeed("touch /srv/empty")
              machine.fail("systemctl start parkrun-scraper.service")
              assert machine.succeed("sqlite3 /srv/site/parkruns.db 'select count(*) from runs'").strip() == "1"
            '';
          };
        }
      );

      devShells = eachSystem (system: {
        default = pkgsFor.${system}.mkShell {
          packages = [
            inputs.self.packages.${system}.parkrun-to-sqlite
            pkgsFor.${system}.sqlite-utils
            pkgsFor.${system}.sqlite
          ];
        };
      });
    };
}
