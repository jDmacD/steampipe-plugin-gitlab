{
  pkgs ? (
    let
      inherit (builtins) fetchTree fromJSON readFile;
      inherit ((fromJSON (readFile ./flake.lock)).nodes) nixpkgs gomod2nix;
    in
    import (fetchTree nixpkgs.locked) {
      overlays = [
        (import "${fetchTree gomod2nix.locked}/overlay.nix")
      ];
    }
  ),
  mkGoEnv ? pkgs.mkGoEnv,
  gomod2nix ? pkgs.gomod2nix,
}:

let
  goEnv = mkGoEnv { pwd = ./.; };
in
pkgs.mkShell {
  packages = [
    goEnv
    gomod2nix
    pkgs.steampipe
    pkgs.commitizen
    pkgs.glab
    pkgs.jq
    pkgs.goreleaser
    pkgs.oras
    (pkgs.writeShellScriptBin "run-tests" ''
      cd "$(git rev-parse --show-toplevel)" && go test -v ./...
    '')
    (pkgs.writeShellScriptBin "query-project" ''
      steampipe --install-dir "$(git rev-parse --show-toplevel)/.steampipe" query "select * FROM gitlab_project WHERE id = 82145074;" --output json
    '')
    (pkgs.writeShellScriptBin "test-tables" (builtins.readFile ./scripts/test-tables.sh))
    (pkgs.writeShellScriptBin "publish" (builtins.readFile ./scripts/publish_oci.sh))
    (pkgs.writeShellScriptBin "release" ''
      set -euo pipefail
      if [[ "''${1:-}" == "--bump" ]]; then
        shift
        cz bump --yes
        git push origin "$(git describe --tags --abbrev=0)"
      fi
      export GITHUB_TOKEN=$(gh auth token)
      goreleaser release --clean "$@"
    '')
  ];
}
