//C++  wrappers
#include <cmath>
#include <cstring>
#include <cstdio>

extern "C" {
    int mocha_cpp_add(int a, int b) {
        return a + b;
    }

    double mocha_cpp_power(double base, double exp) {
        return std::pow(base, exp);
    }

    const char* mocha_cpp_greet(const char* name) {
        static char buffer[256];
        snprintf(buffer, sizeof(buffer), "Hello from C++, %s!", name);
        return buffer;
    }

    int mocha_cpp_strlen(const char* s) {
        return (int)strlen(s);
    }
}