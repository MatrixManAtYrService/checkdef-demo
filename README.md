# Checkdef Demo

This project demonstrates the selective test caching capabilities of the checkdef framework.

## Project Structure

```
├── src/
│   ├── foo/
│   │   ├── __init__.py
│   │   └── main.py          # Slow foo module (10s operations)
│   └── bar/
│       ├── __init__.py
│       └── main.py          # Slow bar module (10s operations)
├── tests/
│   ├── test_foo.py          # Slow foo tests (10s each)
│   └── test_bar.py          # Slow bar tests (10s each)
├── pyproject.toml
├── uv.lock
└── flake.nix                # Complete standalone flake (no blueprint)
```

## Selective Caching Demo

Each module and test intentionally sleeps for 10 seconds to simulate slow operations:
- **No caching**: All tests run = ~40 seconds total
- **With caching**: Only changed tests run = ~20 seconds when only one module changes

## Commands

```bash
# Fast checks (linting only)
nix run .#checklist-linters

# All checks (linting + tests)  
nix run .#checklist-all

# Individual test suites
nix run .#checklist-foo
nix run .#checklist-bar
```

## Demo Steps

1. **First run** (builds everything):
   ```bash
   time nix run .#checklist-all
   # Takes ~40+ seconds (building + running all tests)
   ```

2. **Modify only foo module**:
   ```bash
   # Edit src/foo/main.py - change the return value or add a comment
   ```

3. **Run again**:
   ```bash
   time nix run .#checklist-all  
   # Takes ~20 seconds (foo tests rebuild, bar tests cached)
   ```

4. **Modify only bar module**:
   ```bash
   # Edit src/bar/main.py
   time nix run .#checklist-all
   # Takes ~20 seconds (bar tests rebuild, foo tests cached) 
   ```

This demonstrates how checkdef's `includePatterns` feature enables surgical test execution - only the tests affected by your changes will run, while unaffected tests report cached results.
