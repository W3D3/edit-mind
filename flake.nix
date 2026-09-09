{
  description = "edit-mind dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    prisma-utils.url = "github:VanCoding/nix-prisma-utils";
  };

  outputs = { self, nixpkgs, flake-utils, prisma-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        prisma = prisma-utils.lib.prisma-factory {
          inherit pkgs;
          # leave empty on first run — nix will report the correct hash
          hash = "";
          pnpmLock = ./pnpm-lock.yaml;
        };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            # Node.js + package manager
            nodejs_22
            pnpm

            # Python (ML service; use uv to manage the venv)
            python311
            uv

            # Needed by native Node modules
            openssl
            pkg-config

            # Video processing (background-jobs)
            ffmpeg

            # Utilities
            git
            curl
            jq
          ];

          # Sets PRISMA_QUERY_ENGINE_LIBRARY, PRISMA_SCHEMA_ENGINE_BINARY, etc.
          # to patched binaries that work on NixOS.
          env = prisma.env;

          shellHook = ''
            export PNPM_HOME="$HOME/.local/share/pnpm"
            export PATH="$PNPM_HOME:$PATH"
          '';
        };
      }
    );
}
