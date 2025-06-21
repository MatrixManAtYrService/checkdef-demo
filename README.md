# Speeding up Pytest with Nix

[Checkdef](https://github.com/MatrixManAtYrService/checkdef) is an experimental dev environment consistency check framework.
It's sorta like [pre-commit](https://pre-commit.com), but [nix](https://nix.dev/tutorials/nix-language)ier.

This repository demonstrates one of its checks, which selectively caches pytest runs.
The goal is to only run the tests that might be impacted by a change instead of running all of them each time.
Pytest is used as an example here, but this approach is widely applicable.

## Entire Repo as a Derivation Input

Here are some of the files in this repo.
I've added 5 second delays to each of the python files.

```
├── src/
│   ├── foo/
│   │   └── __init__.py      # prints foo, takes 5 seconds
│   └── bar/
│       └── __init__.py      # prints bar, takes 5 seconds
├── tests/
│   ├── test_foo.py          # checks foo, takes 5 additional seconds
│   └── test_bar.py          # checks bar, takes 5 additional seconds
└── flake.nix                # fun stuff goes here
```

During a typical `pytest` run, all four of these delays would accumulate: it would take at least 20 seconds.

Nix derivations are recipes for some sandboxed compute operation with known inputs.
Normally they are used to build a piece of software.
Here we'll use them to build test results.

The way that nix tracks derivation inputs prevents suprise dependencies (less "works on my machine").
Also since nix notices when the inputs changed, it can sometimes skip the compute step entirely and just provide a cached result.

So building these test results from a derivation that takes the whole repo as an input will take at least 20 seconds.
Subsequent runs wrill be very fast, until we make a change.
Then it will take 20 seconds all over again, even if the change was small.

This wastes a lot of time and money and electricity because so much is spent on testing now what has not changed since it was tested last time.
It gets even worse if you try to use tests as guard rails to keep an AI Agent on the right path:
Either you're waiting forever for tests to run between each change, or today's agent breaks what yesterday's agent built and nobody notices it until after the conversation has moved on and lost the context necessary to fix the problem easily.

## A Segmented Codebase for Smarter Cache Use

We can address this by segmenting the the codebase so that a change causes only the relevant tests to run afresh.

The code below gives us two derivations, each with only a few files as their inputs.
(Other derivation inputs include files that are not part of the repo, things like python packages and the python interpreter).

Note the use of `includePatterns` below, this is an excerpt from [flake.nix](flake.nix).

```nix
# Define an environment builder function
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

# Use the same builder with different filters for cache isolation
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
    "src/bar/**"           # Include all bar source files
    "tests/test_bar.py"    # Include bar test file
  ];
  tests = [ "tests/test_bar.py" ];
  testConfig = {
    extraEnvVars = {
      PYTHONPATH = "src";
    };
  };
};
```

Since both foo-tests and bar-tests depend on `pkgs.python311`, changing it to `pkgs.python312` will trigger a twenty second run.

But a change to `src/foo/__init__.py` will only invalidate the inputs for the `foo-tests` derivation.
`bar-tests` will remain untouched.
So in that case, the tests will only take 10 seconds.

It's a 2x speedup in this example, but it's possible to design for much greater savings.

This differs from how pre-commit decides when to re-run checks because nix is source of truth for whether a derivation's output is cached--not git.
So if you sync `/nix/store` between developers or between CI runners via something like [cachix](https://www.cachix.org/), a run anywhere can speed up identical runs everywhere.

## CLI Usage

```bash
# Run individual test suites
nix run .#checklist-foo
nix run .#checklist-bar

# Run all checks (linters + tests)
nix run .#checklist-all

# Use verbose mode to see detailed execution info
nix run .#checklist-foo -- -v
```

## The Demo

We can see this in action in the video below:
![checkdef-demo](demo.gif)
