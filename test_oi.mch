// mocha-native: f_math.o, @fortran

function f_square(x: int) -> int native f_square;
function f_hello() -> int native f_hello;

function main(didLoad) -> null {
    print(f_square(9), newLine=true);
    print(f_hello(), newLine=true);
};