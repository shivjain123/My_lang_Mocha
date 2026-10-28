//C++  wrappers
// hello_cpp.cpp
#include <cmath>
#include <cstring>
#include <cstdio>

extern "C" {
    char* mocha_ffi_str_copy(const char* s);   // from mocha_runtime.c

    int mocha_cpp_add(int a, int b) {
        return a + b;
    }

    double mocha_cpp_power(double base, double exp) {
        return std::pow(base, exp);
    }

    const char* mocha_cpp_greet(const char* name) {
        char buffer[256];
        snprintf(buffer, sizeof(buffer), "Hello from C++, %s!", name);
        return mocha_ffi_str_copy(buffer);
    }

    int mocha_cpp_strlen(const char* s) {
        return (int)strlen(s);
    }
}