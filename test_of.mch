function ptr_of(a: float[]) -> vast native mocha_ffi_ptr_of;
function ptr_of_int(a: int[]) -> vast native mocha_ffi_ptr_of;

function main(didLoad) -> null {
    var f: float[] = alloc float[2];
    var n: int[] = alloc int[2];
    print(ptr_of(f) == ptr_of(f), newLine=true);
    print(ptr_of_int(n) == ptr_of_int(n), newLine=true);
};