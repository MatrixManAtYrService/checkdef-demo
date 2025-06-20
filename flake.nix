{
  description = "Checkdef demo project showing selective test caching";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    checkdef.url = "github:MatrixManAtYrService/checkdef";
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

          # Define a function that builds the python environment
          # the parameter is some subset of the whole src for this repo
          # (this lets us lean on the nix store to avoid checking again what has already been checked)
          buildPythonEnv = filteredSrc:
            let
              workspace = uv2nix.lib.workspace.loadWorkspace {
                workspaceRoot = filteredSrc;
              };

              pythonSet = (pkgs.callPackage pyproject-nix.build.packages {
                python = pkgs.python311;
              }).overrideScope (
                lib.composeManyExtensions [
                  pyproject-build-systems.overlays.default
                  (workspace.mkPyprojectOverlay { sourcePreference = "wheel"; })
                ]
              );
            in
              pythonSet.mkVirtualEnv "dev-env" workspace.deps.all;

          # provide this project's version of nixpkgs to checkdef
          checks = checkdef.lib pkgs;

          # some checks are so fast they can just get the whole source tree
          # not much is gained by memoizing these
          src = ./.;
          ruffChecks = {
            ruffCheck = checks.ruff-check { inherit src; };
            ruffFormat = checks.ruff-format { inherit src; };
          };

          # other checks are slow enough that you really don't want them running unless their inputs have changed
          # use includePatters to determine which files are this check's inputs
          # Supposing it is run as a derivationCheck, files not indicated here will not be present in the sandbox
          # where this check runs
          foo-tests = checks.pytest-env-builder {
            inherit src;
            envBuilder = buildPythonEnv;
            name = "foo-tests";
            description = "Foo module tests";
            includePatterns = [
              "src/foo/**"
              "tests/test_foo.py"
            ];
            tests = [ "tests/test_foo.py" ];
            testConfig = {
              extraEnvVars = {
                PYTHONPATH = "src";
              };
            };
          };

          bar-tests = checks.pytest-env-builder {
            inherit src;
            envBuilder = buildPythonEnv;
            name = "bar-tests";
            description = "Bar module tests";
            includePatterns = [
              "src/bar/**"
              "tests/test_bar.py"
            ];
            tests = [ "tests/test_bar.py" ];
            testConfig = {
              extraEnvVars = {
                PYTHONPATH = "src";
              };
            };
          };

        in
        rec {
          # Build the actual Python packages from the workspace
          workspace = uv2nix.lib.workspace.loadWorkspace {
            workspaceRoot = src;
          };

          pythonSet = (pkgs.callPackage pyproject-nix.build.packages {
            python = pkgs.python311;
          }).overrideScope (
            lib.composeManyExtensions [
              pyproject-build-systems.overlays.default
              (workspace.mkPyprojectOverlay { sourcePreference = "wheel"; })
            ]
          );

          # The main checkdef-demo package containing foo and bar modules
          checkdef-demo = pythonSet.checkdef-demo;
          default = checkdef-demo;

          # Also expose the development environment
          fullEnv = buildPythonEnv src;

          checklist-linters = checks.runner {
            name = "checklist-linters";
            scriptChecks = ruffChecks;
          };

          checklist-foo = checks.runner {
            name = "checklist-foo";
            derivationChecks = {
              inherit foo-tests;
            };
          };

          checklist-bar = checks.runner {
            name = "checklist-bar";
            derivationChecks = {
              inherit bar-tests;
            };
          };

          checklist-all = checks.runner {
            name = "checklist-all";
            scriptChecks = ruffChecks;
            derivationChecks = {
              inherit foo-tests bar-tests;
            };
          };
        });
    };
}
