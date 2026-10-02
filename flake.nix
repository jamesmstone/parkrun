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
      # `packages.<system>.default` is the scraper CLI, not a site: it writes
      # parkruns.db, which Datasette is pointed at separately.
      packages = eachSystem (system: {
        default = inputs.self.packages.${system}.parkrun-to-sqlite;
        parkrun-to-sqlite = pkgsFor.${system}.python3Packages.callPackage ./parkrun-to-sqlite.nix { };
      });

      checks = eachSystem (system: {
        build = inputs.self.packages.${system}.default;
      });

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
