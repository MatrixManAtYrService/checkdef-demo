"""Tests for bar module."""

import sys
import time
from pathlib import Path

# Add src to path so we can import our modules
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

from bar.main import get_bar, main


def test_get_bar():
    """Test that get_bar returns 'bar' (slow test)."""
    time.sleep(10)  # Simulate slow test setup
    result = get_bar()
    assert result == "bar"


def test_main():
    """Test that main function works correctly."""
    result = main()
    assert result == "bar"
