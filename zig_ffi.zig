const std = @import("std");

export fn mocha_zig_add(a: i32, b: i32) i32 {
    return a + b;
}

export fn mocha_zig_multiply(a: i32, b: i32) i32 {
    return a * b;
}

export fn mocha_zig_fibonacci(n: i32) i32 {
    if (n <= 1) return n;
    var a: i32 = 0;
    var b: i32 = 1;
    var i: i32 = 2;
    while (i <= n) : (i += 1) {
        const c = a + b;
        a = b;
        b = c;
    }
    return b;
}

export fn mocha_zig_factorial(n: i32) i32 {
    if (n <= 1) return 1;
    var result: i32 = 1;
    var i: i32 = 2;
    while (i <= n) : (i += 1) {
        result *= i;
    }
    return result;
}

export fn mocha_zig_power(base: f64, exp: f64) f64 {
    return std.math.pow(f64, base, exp);
}