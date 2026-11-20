// mocha-native: f_arr.o

function ptr_of(a: float[]) -> vast native mocha_ffi_ptr_of;
function f_dot(x: vast, y: vast, n: int) -> float native f_dot;
function f_scale(p: vast, n: int, k: float) -> null native f_scale;

function main(didLoad) -> null {
    var a: float[] = alloc float[3];
    var b: float[] = alloc float[3];
    a[0] = 1.0;
    a[1] = 2.0;
    a[2] = 3.0;
    b[0] = 4.0;
    b[1] = 5.0;
    b[2] = 6.0;
    print(f_dot(ptr_of(a), ptr_of(b), 3), newLine=true);
    f_scale(ptr_of(a), 3, 10.0);
    print(a[2], newLine=true);
};