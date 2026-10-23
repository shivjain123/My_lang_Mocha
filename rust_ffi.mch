// Rust FFI       (rust_add, rust_multiply, rust_fibonacci, rust_factorial)

function rust_add(a: int, b: int) -> int native mocha_rust_add;
function rust_multiply(a: int, b: int) -> int native mocha_rust_multiply;
function rust_fibonacci(n: int) -> int native mocha_rust_fibonacci;
function rust_factorial(n: int) -> int native mocha_rust_factorial;

function section_rust(didLoad) -> null {
    print("--- 3. Rust FFI ---");

    print(rust_add(21, 21));        // 42
    print(rust_multiply(6, 7));     // 42
    print(rust_fibonacci(40));      // 102334155
    print(rust_factorial(10));      // 3628800
};