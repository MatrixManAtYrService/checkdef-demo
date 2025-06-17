"""Bar module with slow operations."""

import time


def get_bar():
    """Get the bar value (slow operation)."""
    time.sleep(5)  # Simulate slow operation
    return "bar"


def main():
    """Main function that prints bar."""
    result = get_bar()
    print(result)


if __name__ == "__main__":
    main()
