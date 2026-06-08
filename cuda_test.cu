#include <stdio.h>

// Forward declare the C API
extern "C" {
    int mocha_cuda_init();
    void* mocha_tensor_new(int rows, int cols);
    void mocha_tensor_set(void* t, int row, int col, float val);
    float mocha_tensor_get(void* t, int row, int col);
    void* mocha_tensor_matmul(void* a, void* b);
    void mocha_tensor_print(void* t);
    void mocha_tensor_free(void* t);
}

int main() {
    mocha_cuda_init();

    // A = [[1, 2], [3, 4]]
    void* A = mocha_tensor_new(2, 2);
    mocha_tensor_set(A, 0, 0, 1.0f);
    mocha_tensor_set(A, 0, 1, 2.0f);
    mocha_tensor_set(A, 1, 0, 3.0f);
    mocha_tensor_set(A, 1, 1, 4.0f);

    // B = [[5, 6], [7, 8]]
    void* B = mocha_tensor_new(2, 2);
    mocha_tensor_set(B, 0, 0, 5.0f);
    mocha_tensor_set(B, 0, 1, 6.0f);
    mocha_tensor_set(B, 1, 0, 7.0f);
    mocha_tensor_set(B, 1, 1, 8.0f);

    void* C = mocha_tensor_matmul(A, B);
    mocha_tensor_print(C);

    // Expected: [[19, 22], [43, 50]]
    mocha_tensor_free(A);
    mocha_tensor_free(B);
    mocha_tensor_free(C);
    return 0;
}