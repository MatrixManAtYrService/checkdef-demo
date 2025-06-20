import time


def get_foo():
    time.sleep(5)  # Simulate slow program
    return "foo"


def main():
    result = get_foo()
    print(result)


if __name__ == "__main__":
    main()
