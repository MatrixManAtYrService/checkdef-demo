# Speeding up Pytest with Nix

[Checkdef](https://github.com/MatrixManAtYrService/checkdef) is an experimental dev environment consistency check framework.
It's sorta like [pre-commit](https://pre-commit.com), but [nix](https://nix.dev/tutorials/nix-language)ier.

This repository demonstrates one of its checks, which selectively caches pytest runs.

## A Problem of Cache Granularity

Here are some files in this repo.
They're not very exciting as python projects go.
I've added 5 second delays so that it's easier to notice when selective caching speeds things up.

```
├── src/
│   ├── foo/
│   │   └── __init__.py      # prints foo, takes 5s
│   └── bar/
│       └── __init__.py      # prints bar, takes 5s
├── tests/
│   ├── test_foo.py          # checks foo, takes 5s
│   └── test_bar.py          # checks bar, takes 5s
└── flake.nix                # fun stuff goes here
```

Normally, every time you run `pytest`, **all** tests would run.
In this scenario, that would take 20 seconds.

Nix lets you create "derivations" which are recipes for some sandboxed compute operation with known inputs.
Normally it is used to build a piece of software.
But it also works for "building" test results.

A benefit to this is that you get precise control over what goes in the sandbox (no more "works on my machine", no more differences between CI and local).
But also, since it knows what the derivation's inputs are, nix can notice when they change.
If the inputs have not changed, nix will skip the compute step and just provide a cached output.

So if we made a derivation for our pytest environment, it would take 20 seconds the first time, and then less than a second the second time.
That is, unless we changed something.
Then it would take 20 seconds all over again, even if the change was small.

This wastes a lot of time and money and electricity (locally, and in CI), because so much is spent testing today what has not changed since it was tested yesterday.
It gets even worse if you try to use tests as guard rails to keep an AI Agent on the right path:
Either you're waiting forever for tests to run between each change, or today's agent breaks what yesterday's agent built and nobody notices it until after the conversation has moved on and lost the context necessary to fix the problem easily.

## A Segmented Codebase for Smarter Cache Use

We can address this by segmenting the the codebase so that only the relevant tests get a fresh run.

The code below gives us two sandboxes, each contains just what is necessary for a certain batch of tests.
Note the use of `includePatterns` below, this is an excerpt from [flake.nix](flake.nix).

```nix
# Define your environment builder function
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

Installing a new package will change `uv.lock` and will invalidate the cache for both checks.
Running all tests will take the full 20 seconds or so.

But a change to `src/foo/__init__.py` will only invalidate the inputs for the `foo-tests` derivation.
`bar-tests` will remain untouched.
So in that case, the tests will only take 10 seconds.

It's a 2x speedup in this example, but if you have several test suites and your changes are relevant only to one of them, the savings could be significantly greater.

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
