// mocha-native: f_math.o, C:\mingw64\mingw64\lib\libgfortran.a, C:\mingw64\mingw64\lib\libquadmath.a, C:\mingw64\mingw64\x86_64-w64-mingw32\lib\libwinpthread.a

function f_square(x: int) -> int native f_square;
function f_hello() -> int native f_hello;

function main(didLoad) -> null {
    print(f_square(9), newLine=true);
    print(f_hello(), newLine=true);
};