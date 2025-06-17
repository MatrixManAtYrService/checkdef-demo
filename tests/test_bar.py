import time

from bar import get_bar


def test_get_bar():
    time.sleep(5)  # Simulate slow test
    result = get_bar()
    assert result == "bar"
