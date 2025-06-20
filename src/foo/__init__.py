import time


def get_foo():
    time.sleep(5)  # Simulate slow program
    return "foo"


def main():
    result = get_foo()
    print(result)


if __name__ == "__main__":
    main()
# force rebuild
# force rebuild 2
# force rebuild Tue Jun 17 14:10:02 MDT 2025
# force rebuild again Tue Jun 17 14:10:31 MDT 2025
# force rebuild direct test Tue Jun 17 14:11:17 MDT 2025
# force rebuild normal test Tue Jun 17 14:11:45 MDT 2025
# force checklist rebuild Tue Jun 17 14:12:16 MDT 2025
# force rebuild
# test timing
# cache bust# cache bust test
