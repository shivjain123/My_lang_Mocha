// mocha-native: C:\nimwork\libnim_math.a, C:\mingw64\mingw64\x86_64-w64-mingw32\lib\libwinpthread.a

function nim_init() -> null native NimMain;
function nim_square(x: int) -> int native nim_square;
function nim_sum_to(n: int) -> int native nim_sum_to;
function nim_hello() -> int native nim_hello;

function main(didLoad) -> null {
    nim_init();
    print(nim_square(9), newLine=true);
    print(nim_sum_to(10), newLine=true);
    print(nim_hello(), newLine=true);
};