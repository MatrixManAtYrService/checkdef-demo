{
  description = "Checkdef demo project showing selective test caching";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    checkdef.url = "path:/Users/matt/src/checkdef";
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs = {
        pyproject-nix.follows = "pyproject-nix";
        nixpkgs.follows = "nixpkgs";
      };
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs = {
        pyproject-nix.follows = "pyproject-nix";
        uv2nix.follows = "uv2nix";
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs = { self, nixpkgs, checkdef, pyproject-nix, uv2nix, pyproject-build-systems }:
    let
      inherit (nixpkgs) lib;
      forAllSystems = lib.genAttrs [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          # Load the workspace from uv.lock
          workspace = uv2nix.lib.workspace.loadWorkspace {
            workspaceRoot = ./.;
          };

          # Create the python package set
          pythonSet = (pkgs.callPackage pyproject-nix.build.packages {
            python = pkgs.python311;
          }).overrideScope (
            lib.composeManyExtensions [
              pyproject-build-systems.overlays.default
              (workspace.mkPyprojectOverlay { sourcePreference = "wheel"; })
            ]
          );

          # Build the Python environment (includes all dependency groups)
          pythonEnv = pythonSet.mkVirtualEnv "dev-env" workspace.deps.all;

          # provide this project's version of nixpkgs to checkdef
          checks = checkdef.lib pkgs;

          src = ./.;

          ruffChecks = {
            ruffCheck = checks.ruff-check { inherit src; };
            ruffFormat = checks.ruff-format { inherit src; };
          };

          fooChecks = checks.pytest-cached {
            inherit src pythonEnv;
            name = "foo-tests";
            description = "Foo module tests (cached)";
            includePatterns = [
              "src/foo/**"
              "tests/test_foo.py"
              "pyproject.toml"
            ];
            testDirs = [ "tests/test_foo.py" ];
          };

          barChecks = checks.pytest-cached {
            inherit src pythonEnv;
            name = "bar-tests";
            description = "Bar module tests (cached)";
            includePatterns = [
              "src/bar/**"
              "tests/test_bar.py"
              "pyproject.toml"
            ];
            testDirs = [ "tests/test_bar.py" ];
          };

        in
        rec {
          checkdef-demo = pythonSet.checkdef-demo;
          default = checkdef-demo;

          checklist-linters = checks.runner {
            name = "linter-checks";
            scriptChecks = ruffChecks;
          };

          checklist-foo = checks.runner {
            name = "foo-checks";
            derivationChecks = fooChecks;
          };

          checklist-bar = checks.runner {
            name = "bar-checks";
            derivationChecks = barChecks;
          };

          checklist-all = checks.runner {
            name = "all-checks";
            scriptChecks = ruffChecks;
            derivationChecks = {
              fooTests = fooChecks;
              barTests = barChecks;
            };
          };
        });
    };
}
