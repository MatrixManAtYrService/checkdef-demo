"""Foo module with slow operations."""

import time


def get_foo():
    """Get the foo value (slow operation)."""
    time.sleep(10)  # Simulate slow operation
    return "foo"


def main():
    """Main function that prints foo."""
    result = get_foo()
    print(result)


if __name__ == "__main__":
    main()
# Modified at Mon Jun 16 15:19:54 MDT 2025
