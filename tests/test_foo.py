import time

from foo import get_foo


def test_get_foo():
    time.sleep(5)  # Simulate slow test
    result = get_foo()
    assert result == "foo"
print("debug change")
