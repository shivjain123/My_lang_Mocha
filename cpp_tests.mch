// C++ FFI
function cpp_add(a: int, b: int) -> int native mocha_cpp_add;
function cpp_power(base: float, exp: float) -> float native mocha_cpp_power;
function cpp_greet(name: str) -> str native mocha_cpp_greet;
function cpp_strlen(s: str) -> int native mocha_cpp_strlen;

function cpp(didLoad) -> null {
    print("--- 1. C++ FFI ---");

    var sum: int = cpp_add(21, 21);
    print(sum);           // 42

    var p: float = cpp_power(2.0, 10.0);
    print(p);             // 1024.0

    var greeting: str = cpp_greet("Mocha");
    print(greeting);           // Hello from C++!

    var len: int = cpp_strlen("Hello Mocha!");
    print(len);           // 12
};