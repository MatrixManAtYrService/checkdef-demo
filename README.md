# Checkdef Demo

[Checkdef](https://github.com/MatrixManAtYrService) is an experimental dev environment consistency check framework.
(It's sorta like [pre-commit](https://pre-commit.com), but nixier.)

This repository demonstrates one of its checks, which selectively caches test inputs.

## A Problem of Cache Granularity

```
├── src/
│   ├── foo/
│   │   ├── __init__.py
│   │   └── main.py          # Slow foo module (5s)
│   └── bar/
│       ├── __init__.py
│       └── main.py          # Slow bar module (5s)
├── tests/
│   ├── test_foo.py          # Slow foo tests (5s)
│   └── test_bar.py          # Slow bar tests (5s)
└── flake.nix
```

`foo` is just a program that prints `foo`.
`bar` prints `bar`.
Their tests just assert that they do indeed print those things.
I've added 5 second delays so that it's easier to notice when selective caching speeds things up.

Normally, every time you run `pytest`, **all** tests would run.
In this scenario, that would take 20 seconds.

Nix lets you create "derivations" which are recipes for some sandboxed compute operation with known inputs.
Normally we imagine this as a compiler or a linker operation... something that spits out a piece of software.
But it also works for "building" test results.

One benefit to this is that you have precise control over what goes in the sandbox (no more "works on my machine").
But also, since it knows what the derivation's inputs are, nix can notice when they change.
If the inputs have not changed, nix will skip the compute step and just provide a cached output.

So if we made a derivation for our pytest environment, it would take 20 seconds the first time, and then less than a second the second time.
That is, unless we changed something.
Then it would take 20 seconds all over again, even if the change was small.

This wastes a lot of time and money and electricity (locally, and in CI), because so much is spent testing today what has not changed since it was tested yesterday.
It gets even worse if you try to use tests as guard rails to keep an AI Agent on the right path:
Either you're waiting forever for tests to run between each change, or today's agent breaks what yesterday's agent built and nobody notices it until after the conversation has moved on and lost the context necessary to fix the problem easily.

## The Checkdef Solution

We can address this by segmenting the the codebase.

The code below gives us two sandboxes, each contains just what is necessary for a certain batch of tests.
Note the use of `includePatterns` below, this is an excerpt from [flake.nix](flake.nix).

```nix
fooChecks = checks.pytest-cached {
  inherit src pythonEnv;
  name = "foo-tests";
  description = "Foo module tests";
  includePatterns = [
    "src/foo/**"
    "tests/test_foo.py"
    "pyproject.toml"
  ];
  tests = [ "tests/test_foo.py" ];
};

barChecks = checks.pytest-cached {
  inherit src pythonEnv;
  name = "bar-tests";
  description = "Bar module tests";
  includePatterns = [
    "src/bar/**"
    "tests/test_bar.py"
    "pyproject.toml"
  ];
  tests = [ "tests/test_bar.py" ];
};
```

Installing a new package will cause a change to `pythonEnv`, invalidating the cache for both checks.
All tests will run and it will take the full 20 seconds.

But a change to `src/foo/__init__.py` will only invalidate the inputs for the `fooChecks` derivation.
`barChecks` will remain untouchd.
So in that case, the tests will only take 10 seconds.

## The Demo

We can see this in action in the video below:
![checkdef-demo](demo.gif)

