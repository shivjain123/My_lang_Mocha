function fib(n: int) -> int {
    if (n <= 1) { return n; };
    return fib(n - 1) + fib(n - 2);
};

function main(didLoad) -> null {
    print(fib(40));
};