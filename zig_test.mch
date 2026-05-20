//Zig Test
function zig_add(a: int, b: int) -> int native mocha_zig_add;
function zig_multiply(a: int, b: int) -> int native mocha_zig_multiply;
function zig_fibonacci(n: int) -> int native mocha_zig_fibonacci;
function zig_factorial(n: int) -> int native mocha_zig_factorial;
function zig_power(base: float, exp: float) -> float native mocha_zig_power;

function zig_test(didLoad) -> null {
    print("=== Zig FFI Test ===", newLine=true);

    // Basic arithmetic
    var a: int = zig_add(10, 25);
    print("add(10, 25) = ", a, newLine=true);        // 35

    var m: int = zig_multiply(6, 7);
    print("multiply(6, 7) = ", m, newLine=true);     // 42

    // Fibonacci
    print("fibonacci(0) = ", zig_fibonacci(0), newLine=true);   // 0
    print("fibonacci(1) = ", zig_fibonacci(1), newLine=true);   // 1
    print("fibonacci(10) = ", zig_fibonacci(10), newLine=true); // 55
    print("fibonacci(20) = ", zig_fibonacci(20), newLine=true); // 6765

    // Factorial
    print("factorial(0) = ", zig_factorial(0), newLine=true);   // 1
    print("factorial(1) = ", zig_factorial(1), newLine=true);   // 1
    print("factorial(5) = ", zig_factorial(5), newLine=true);   // 120
    print("factorial(10) = ", zig_factorial(10), newLine=true); // 3628800

    // Power
    print("power(2.0, 10.0) = ", zig_power(2.0, 10.0), newLine=true);   // 1024.0
    print("power(3.0, 3.0) = ", zig_power(3.0, 3.0), newLine=true);     // 27.0
    print("power(2.0, 0.5) = ", zig_power(2.0, 0.5), newLine=true);     // ~1.4142

    print("=== Zig FFI Test Done ===", newLine=true);
};