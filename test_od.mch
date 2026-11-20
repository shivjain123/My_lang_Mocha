function ptr_of(a: float[]) -> vast native mocha_ffi_ptr_of;

function main(didLoad) -> null {
    var g: float[] = [];
    g.push(1.0);
    print("before", newLine=true);
    print(ptr_of(g), newLine=true);
    print("after", newLine=true);
};