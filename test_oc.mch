// mocha-native: d_arr.o

function ptr_of(a: float[]) -> vast native mocha_ffi_ptr_of;
function d_sum(p: vast, n: int) -> float native d_sum;
function d_double_all(p: vast, n: int) -> null native d_double_all;

function main(didLoad) -> null {
    var a: float[] = alloc float[4];
    a[0] = 1.0;
    a[1] = 2.0;
    a[2] = 3.0;
    a[3] = 4.0;
    print(d_sum(ptr_of(a), 4), newLine=true);
    d_double_all(ptr_of(a), 4);
    print(a[2], newLine=true);
};