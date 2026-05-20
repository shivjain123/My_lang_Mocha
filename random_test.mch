from "mocha-math" import *;

function test(didLoad) -> null {
    rand_seed(42);
    print(str(rand_int(0, 10)), newLine=true);
    print(str(rand_int(0, 10)), newLine=true);
    print(str(rand_int(0, 10)), newLine=true);
    print(str(rand_float(0.0, 1.0)), newLine=true);
    print(str(rand_float(0.0, 1.0)), newLine=true);
};