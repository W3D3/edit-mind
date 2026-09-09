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

        # nix-prisma-utils reads engines-version 7.x from pnpm-lock and skips the
        # query engine library (only needed for engines <7 in their logic). But Prisma
        # CLI 6.19.3 still ships with engines-version 7.x and still needs
        # libquery_engine.so.node at runtime on NixOS. We fetch the debian build and
        # patchelf it so it resolves its shared library dependencies in the nix store.
        prismaQueryEngineLib =
          let
            src = pkgs.fetchurl {
              url = "https://binaries.prisma.sh/all_commits/c2990dca591cba766e3b7ef5d9e8a84796e47ab7/debian-openssl-3.0.x/libquery_engine.so.node.gz";
              hash = "sha256-04CHLMihcxDG67JJ3AAPT8v7vVHdw2vrV7HtDFTG1hA=";
            };
          in
          pkgs.stdenvNoCC.mkDerivation {
            name = "prisma-query-engine-lib-c2990dca";
            nativeBuildInputs = [ pkgs.autoPatchelfHook pkgs.gzip ];
            buildInputs = [ pkgs.openssl pkgs.stdenv.cc.cc.lib pkgs.zlib ];
            phases = [ "installPhase" ];
            installPhase = ''
              mkdir -p $out/lib
              gunzip -c ${src} > $out/lib/libquery_engine.so.node
            '';
            dontStrip = true;
          };

        prisma = prisma-utils.lib.prisma-factory {
          inherit pkgs;
          hash = "sha256-JnuIC5XKRH3puMpoFR45Js97owOmrhH6srpmXs2GCVc=";
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

          # Sets PRISMA_SCHEMA_ENGINE_BINARY, PRISMA_FMT_BINARY, etc.
          env = prisma.env // {
            PRISMA_QUERY_ENGINE_LIBRARY = "${prismaQueryEngineLib}/lib/libquery_engine.so.node";
          };

          shellHook = ''
            export PNPM_HOME="$HOME/.local/share/pnpm"
            export PATH="$PNPM_HOME:$PATH"
          '';
        };
      }
    );
}
