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
      # Development shells - let's start with this to generate the lockfile
      devShells = forAllSystems (system: {
        default = let
          pkgs = nixpkgs.legacyPackages.${system};
        in pkgs.mkShell {
          packages = [
            pkgs.uv
            pkgs.python311
          ];
          
          shellHook = ''
            echo "🚀 Checkdef Demo Development Environment"
            echo ""
            echo "First run: uv lock  (to generate uv.lock)"
            echo "Then you can use the other nix commands..."
          '';
        };
      });

      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          # Load the workspace from uv.lock (once it exists)
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

          # Get checkdef
          checks = checkdef.lib pkgs;

          src = ./.;

        in
        {
          default = self.packages.${system}.all-checks;

          foo-tests = checks.pytest-cached {
            inherit src pythonEnv;
            name = "foo-tests";
            description = "Foo module tests (cached)";
            # Use glob patterns - much simpler and more intuitive!
            includePatterns = [ 
              "src/foo/**"          # Include entire foo module
              "tests/test_foo.py"   # Include foo tests
              "pyproject.toml"      # Include config
            ];
            testDirs = [ "tests/test_foo.py" ];
          };

          bar-tests = checks.pytest-cached {
            inherit src pythonEnv;
            name = "bar-tests"; 
            description = "Bar module tests (cached)";
            # Use glob patterns - much simpler and more intuitive!
            includePatterns = [
              "src/bar/**"          # Include entire bar module
              "tests/test_bar.py"   # Include bar tests  
              "pyproject.toml"      # Include config
            ];
            testDirs = [ "tests/test_bar.py" ];
          };

          # Fast checks (linting, formatting)
          fast-checks = checks.makeCheckScript {
            name = "fast-checks";
            suiteName = "Fast Checks";
            scriptChecks = {
              ruffCheck = checks.ruff-check { inherit src; };
              ruffFormat = checks.ruff-format { inherit src; };
            };
          };

          # Full checks (includes cached tests)
          all-checks = checks.makeCheckScript {
            name = "all-checks";
            suiteName = "All Checks";
            scriptChecks = {
              ruffCheck = checks.ruff-check { inherit src; };
              ruffFormat = checks.ruff-format { inherit src; };
            };
            derivationChecks = {
              fooTests = self.packages.${system}.foo-tests;
              barTests = self.packages.${system}.bar-tests;
            };
          };
        });

      apps = forAllSystems (system: {
        default = self.apps.${system}.all-checks;
        
        fast-checks = {
          type = "app";
          program = "${self.packages.${system}.fast-checks}/bin/fast-checks";
        };
        
        all-checks = {
          type = "app";
          program = "${self.packages.${system}.all-checks}/bin/all-checks";
        };

        foo-tests = {
          type = "app";
          program = "${self.packages.${system}.foo-tests}/bin/foo-tests";
        };

        bar-tests = {
          type = "app";
          program = "${self.packages.${system}.bar-tests}/bin/bar-tests";
        };
      });
    };
}
