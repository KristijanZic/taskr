{
  description = "Build a cargo project which uses axum";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    crane.url = "github:ipetkov/crane";

    flake-utils.url = "github:numtide/flake-utils";

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      crane,
      flake-utils,
      fenix,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        inherit (pkgs) lib;

        # Get the fenix packages for the current system
        fenixPkgs = fenix.packages.${system};

        # Combine the components you need into a single toolchain
        rustToolchain = fenixPkgs.stable.withComponents [
          "cargo"
          "clippy"
          "rust-src"
          "rustc"
          "rustfmt"
          "rust-analyzer"
        ];

        # Tell crane to use your combined fenix toolchain
        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;

        unfilteredRoot = ./.; # The original, unfiltered source
        src = lib.fileset.toSource {
          root = unfilteredRoot;
          fileset = lib.fileset.unions [
            # Default files from crane (Rust and cargo files)
            (craneLib.fileset.commonCargoSources unfilteredRoot)
            # Include all the .sql migrations as well
            # ./migrations
          ];
        };

        # Common arguments can be set here to avoid repeating them later
        commonArgs = {
          inherit src;
          strictDeps = true;

          nativeBuildInputs = [
            pkgs.pkg-config
          ];

          buildInputs = [
            # Add additional build inputs here
          ];

          # Additional environment variables can be set directly
          # MY_CUSTOM_VAR = "some value";
        };

        # Build *just* the cargo dependencies, so we can reuse
        # all of that work (e.g. via cachix) when running in CI
        cargoArtifacts = craneLib.buildDepsOnly commonArgs;

        # Build the actual crate itself, reusing the dependency
        # artifacts from above.
        my-crate = craneLib.buildPackage (
          commonArgs
          // {
            inherit cargoArtifacts;

            nativeBuildInputs = (commonArgs.nativeBuildInputs or [ ]) ++ [
            ];

          }
        );
      in
      {
        checks = {
          # Build the crate as part of `nix flake check` for convenience
          inherit my-crate;

          # Add clippy and fmt checks that automatically use the fenix toolchain
          my-crate-clippy = craneLib.cargoClippy (
            commonArgs
            // {
              inherit cargoArtifacts;
              cargoClippyExtraArgs = "--all-targets -- --deny warnings";
            }
          );

          my-crate-fmt = craneLib.cargoFmt {
            inherit src;
          };
        };

        packages = {
          default = my-crate;
          inherit my-crate;
        };

        devShells.default = craneLib.devShell {
          # Inherit inputs from checks.
          # checks = self.checks.${system};

          # This si so that rust_analyzer in zed works:
          RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";

          # Extra inputs can be added here; cargo and rustc are provided by default.
          packages = [
          ];

          shellHook = lib.optionalString pkgs.stdenv.isDarwin ''
            # xcode-select -p actually honors DEVELOPER_DIR if it's already set
            # — it doesn't only report the system-selected Xcode, it echoes back the override if one is active.
            # Since the nix apple-sdk setup hook exports DEVELOPER_DIR to the nix-store path before your shellHook runs,
            # calling xcode-select -p inside the shellHook just reads its own already-poisoned env var and returns it right back to you
            # — a circular reference. That's why it looks like the fix "didn't take" even though it should run.
            # export DEVELOPER_DIR=$(/usr/bin/xcode-select -p)

            # env -u DEVELOPER_DIR strips the variable just for that one invocation,
            # so xcode-select is forced to consult the real system Xcode selection
            # instead of parroting the nix value.
            export DEVELOPER_DIR=$(env -u DEVELOPER_DIR /usr/bin/xcode-select -p)
          '';
        };
      }
    );
}
