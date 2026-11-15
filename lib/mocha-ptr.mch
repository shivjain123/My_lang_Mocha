"""
   MochaPtr v0.1 — raw array addresses for native code (Rust, C++, D, Fortran ...)
   Save as: lib/mocha-ptr.mch
   Compile with: mocha libs ptr

   Rules:
   - Only fixed-size arrays (made with alloc) are accepted. A growing array can move
     in memory, so it is refused with a loud runtime error.
   - Keep the array in a variable while the native call runs. Never pass a temporary
     like ptr_of_float(make_array()).
   - The element type must match what the native code expects (float[] = double*,
     int[] = int32*, vast[] = int64*). Mocha cannot check that for you.
"""

function ptr_of_float(a: float[]) -> vast native mocha_ffi_ptr_of;
function ptr_of_int(a: int[]) -> vast native mocha_ffi_ptr_of;
function ptr_of_vast(a: vast[]) -> vast native mocha_ffi_ptr_of;
function ptr_of_bool(a: bool[]) -> vast native mocha_ffi_ptr_of;

// 2D arrays are separate rows in memory, so native code cannot take them directly.
// flatten copies a matrix into ONE flat fixed-size array, row after row (row-major),
// which is what C and Rust expect. Fortran is column-major and would read it transposed.
function flatten(m: float[][]) -> float[] {
    var rows: int = m.length;
    var cols: int = m.cols;
    var out: float[] = alloc float[rows * cols];
    var r: int = 0;
    while (r < rows) {
        var c: int = 0;
        while (c < cols) {
            out[r * cols + c] = m[r][c];
            c++;
        };
        r++;
    };
    return out;
};

function unflatten(flat: float[], rows: int, cols: int) -> float[][] {
    if (flat.length != rows * cols) {
        fail "unflatten: array length does not match rows * cols";
    };
    var out: float[][] = alloc float[rows][cols];
    var r: int = 0;
    while (r < rows) {
        var c: int = 0;
        while (c < cols) {
            out[r][c] = flat[r * cols + c];
            c++;
        };
        r++;
    };
    return out;
};