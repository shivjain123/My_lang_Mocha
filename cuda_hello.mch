function mocha_cuda_init() -> int native mocha_cuda_init;
function mocha_tensor_new(rows: int, cols: int) -> vast native mocha_tensor_new;
function mocha_tensor_set(t: vast, row: int, col: int, val: float) -> null native mocha_tensor_set;
function mocha_tensor_matmul(a: vast, b: vast) -> vast native mocha_tensor_matmul;
function mocha_tensor_print(t: vast) -> null native mocha_tensor_print;
function mocha_tensor_free(t: vast) -> null native mocha_tensor_free;

function main(didLoad) -> null {
    mocha_cuda_init();

    var a: vast = mocha_tensor_new(2, 2);
    mocha_tensor_set(a, 0, 0, 1.0);
    mocha_tensor_set(a, 0, 1, 2.0);
    mocha_tensor_set(a, 1, 0, 3.0);
    mocha_tensor_set(a, 1, 1, 4.0);

    var b: vast = mocha_tensor_new(2, 2);
    mocha_tensor_set(b, 0, 0, 5.0);
    mocha_tensor_set(b, 0, 1, 6.0);
    mocha_tensor_set(b, 1, 0, 7.0);
    mocha_tensor_set(b, 1, 1, 8.0);

    var c: vast = mocha_tensor_matmul(a, b);
    mocha_tensor_print(c);

    mocha_tensor_free(a);
    mocha_tensor_free(b);
    mocha_tensor_free(c);
};