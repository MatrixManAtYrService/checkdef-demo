"""Tests for foo module."""

import sys
import time
from pathlib import Path

# Add src to path so we can import our modules
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

from foo.main import get_foo, main


def test_get_foo():
    """Test that get_foo returns 'foo' (slow test)."""
    time.sleep(10)  # Simulate slow test setup
    result = get_foo()
    assert result == "foo"


def test_main():
    """Test that main function works correctly."""
    result = main()
    assert result == "foo"
