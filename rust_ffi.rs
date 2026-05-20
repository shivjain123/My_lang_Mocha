#![no_std]
#![no_main]

use core::panic::PanicInfo;

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}

// Dummy eh_personality to satisfy linker
#[no_mangle]
pub extern "C" fn rust_eh_personality() {}

#[no_mangle]
pub extern "C" fn mocha_rust_add(a: i32, b: i32) -> i32 {
    a + b
}

#[no_mangle]
pub extern "C" fn mocha_rust_multiply(a: i32, b: i32) -> i32 {
    a * b
}

#[no_mangle]
pub extern "C" fn mocha_rust_fibonacci(n: i32) -> i32 {
    if n <= 1 { return n; }
    let mut a = 0i32;
    let mut b = 1i32;
    let mut i = 2i32;
    while i <= n {
        let c = a + b;
        a = b;
        b = c;
        i += 1;
    }
    b
}

#[no_mangle]
pub extern "C" fn mocha_rust_factorial(n: i32) -> i32 {
    if n <= 1 { return 1; }
    let mut result = 1i32;
    let mut i = 2i32;
    while i <= n {
        result *= i;
        i += 1;
    }
    result
}