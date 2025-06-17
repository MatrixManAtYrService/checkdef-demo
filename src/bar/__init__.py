import time


def get_bar():
    time.sleep(5)  # Simulate slow program
    return "bar"


def main():
    result = get_bar()
    print(result)


if __name__ == "__main__":
    main()
