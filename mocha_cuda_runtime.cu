/*
 * mocha_cuda_runtime.cu
 * Low-level CUDA + cuBLAS backend for mocha-neuron.
 * Compiled with: nvcc -O3 -arch=sm_60 -shared -o mocha_cuda_runtime.lib mocha_cuda_runtime.cu -lcublas
 *
 * sm_60 = Pascal baseline — JIT-compiles to native on any CUDA GPU at first run
 * 
 * sm_86 = RTX 3050 (Ampere architecture) #My own
 *
 * Exposes a pure C API so Mocha can call these via `native`.
 */

#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <cuda_fp16.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

/* ── cuBLAS handle (one per process) ─────────────────────────────────────── */

static cublasHandle_t g_cublas = NULL;
static int g_initialized       = 0;

extern "C" int mocha_cuda_init() {
    if (g_initialized) return 1;
    cudaError_t ce = cudaSetDevice(0);
    if (ce != cudaSuccess) {
        fprintf(stderr, "[mocha-cuda] cudaSetDevice failed: %s\n", cudaGetErrorString(ce));
        return 0;
    }
    cublasStatus_t cs = cublasCreate(&g_cublas);
    if (cs != CUBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "[mocha-cuda] cublasCreate failed: %d\n", cs);
        return 0;
    }
    /* Enable Tensor Core mixed precision (fp16 compute, fp32 accumulate) */
    cublasSetMathMode(g_cublas, CUBLAS_TF32_TENSOR_OP_MATH);
    g_initialized = 1;
    return 1;
}

extern "C" void mocha_cuda_shutdown() {
    if (g_cublas) { cublasDestroy(g_cublas); g_cublas = NULL; }
    cudaDeviceReset();
    g_initialized = 0;
}

/* ── Tensor struct ────────────────────────────────────────────────────────── */
/*
 * All data lives in two places:
 *   host_data  — CPU float32 array (always valid after download)
 *   dev_data   — GPU float32 array (valid when on_gpu == 1)
 *
 * Layout: row-major flat array, index = row * cols + col
 */

typedef struct {
    float* host_data;
    float* dev_data;
    int    rows;
    int    cols;
    int    on_gpu;   /* 1 = dev_data is current, 0 = host_data is current */
} MochaTensor;

/* ── Allocation ───────────────────────────────────────────────────────────── */

extern "C" MochaTensor* mocha_tensor_new(int rows, int cols) {
    MochaTensor* t = (MochaTensor*)calloc(1, sizeof(MochaTensor));
    t->rows      = rows;
    t->cols      = cols;
    t->host_data = (float*)calloc(rows * cols, sizeof(float));
    t->dev_data  = NULL;
    t->on_gpu    = 0;
    return t;
}

extern "C" MochaTensor* mocha_tensor_from_array(double* data, int rows, int cols) {
    MochaTensor* t = mocha_tensor_new(rows, cols);
    for (int i = 0; i < rows * cols; i++) {
        t->host_data[i] = (float)data[i];
    }
    return t;
}

extern "C" void mocha_tensor_free(MochaTensor* t) {
    if (!t) return;
    if (t->host_data) free(t->host_data);
    if (t->dev_data)  cudaFree(t->dev_data);
    free(t);
}

/* ── Host ↔ Device transfers ──────────────────────────────────────────────── */

extern "C" int mocha_tensor_upload(MochaTensor* t) {
    if (!mocha_cuda_init()) return 0;
    int n = t->rows * t->cols;
    if (!t->dev_data) {
        cudaMalloc((void**)&t->dev_data, n * sizeof(float));
    }
    cudaMemcpy(t->dev_data, t->host_data, n * sizeof(float), cudaMemcpyHostToDevice);
    t->on_gpu = 1;
    return 1;
}

extern "C" int mocha_tensor_download(MochaTensor* t) {
    if (!t->dev_data) return 0;
    int n = t->rows * t->cols;
    cudaMemcpy(t->host_data, t->dev_data, n * sizeof(float), cudaMemcpyDeviceToHost);
    t->on_gpu = 0;
    return 1;
}

/* ── Accessors ────────────────────────────────────────────────────────────── */

extern "C" double mocha_tensor_get(MochaTensor* t, int row, int col) {
    if (t->on_gpu) mocha_tensor_download(t);
    return (double)t->host_data[row * t->cols + col];
}

extern "C" MochaTensor* mocha_tensor_get_row(MochaTensor* t, int row) {
    if (t->on_gpu) mocha_tensor_download(t);
    MochaTensor* result = mocha_tensor_new(1, t->cols);
    for (int j = 0; j < t->cols; j++) {
        result->host_data[j] = t->host_data[row * t->cols + j];
    }
    return result;
}

extern "C" void mocha_tensor_set(MochaTensor* t, int row, int col, double val) {
    if (t->on_gpu) mocha_tensor_download(t);
    t->host_data[row * t->cols + col] = (float)val;
}

extern "C" int mocha_tensor_rows(MochaTensor* t) { return t->rows; }
extern "C" int mocha_tensor_cols(MochaTensor* t) { return t->cols; }

/* ── Matrix multiply: C = A @ B ───────────────────────────────────────────── */
/*
 * Uses cuBLAS SGEMM with Tensor Cores.
 * cuBLAS is column-major internally, so we compute B^T @ A^T = C^T
 * which gives us the correct row-major result without any transposition cost.
 *
 * A: [M x K]   B: [K x N]   C: [M x N]
 */

extern "C" MochaTensor* mocha_tensor_matmul(MochaTensor* A, MochaTensor* B) {
    if (!mocha_cuda_init()) return NULL;

    int M = A->rows, K = A->cols, N = B->cols;
    if (K != B->rows) {
        fprintf(stderr, "[mocha-cuda] matmul shape mismatch: [%d x %d] @ [%d x %d]\n",
                M, K, B->rows, N);
        return NULL;
    }

    /* Upload if not already on GPU */
    if (!A->on_gpu) mocha_tensor_upload(A);
    if (!B->on_gpu) mocha_tensor_upload(B);

    MochaTensor* C = mocha_tensor_new(M, N);
    cudaMalloc((void**)&C->dev_data, M * N * sizeof(float));
    C->on_gpu = 1;

    const float alpha = 1.0f, beta = 0.0f;

    /* cublasSgemm(handle, transB, transA, N, M, K, alpha, B, N, A, K, beta, C, N) */
    cublasStatus_t st = cublasSgemm(
        g_cublas,
        CUBLAS_OP_N, CUBLAS_OP_N,
        N, M, K,
        &alpha,
        B->dev_data, N,
        A->dev_data, K,
        &beta,
        C->dev_data, N
    );

    if (st != CUBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "[mocha-cuda] cublasSgemm failed: %d\n", st);
        mocha_tensor_free(C);
        return NULL;
    }

    return C;
}

/* ── Fused kernels ────────────────────────────────────────────────────────── */
/*
 * These do activation + optional bias in ONE GPU pass after matmul.
 * Avoids a second kernel launch and extra memory bandwidth.
 * This is the "modern" part — cuBLAS doesn't fuse these for you.
 */

/* ReLU: max(0, x) */
__global__ void kernel_relu(float* data, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) data[i] = fmaxf(0.0f, data[i]);
}

/* ReLU + bias add fused */
__global__ void kernel_relu_bias(float* data, float* bias, int rows, int cols) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < rows * cols) {
        int col = i % cols;
        data[i] = fmaxf(0.0f, data[i] + bias[col]);
    }
}

/* Sigmoid: 1 / (1 + e^-x) */
__global__ void kernel_sigmoid(float* data, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) data[i] = 1.0f / (1.0f + expf(-data[i]));
}

/* Tanh */
__global__ void kernel_tanh_act(float* data, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) data[i] = tanhf(data[i]);
}

/* Softmax — one row at a time, numerically stable */
__global__ void kernel_softmax(float* data, int rows, int cols) {
    int row = blockIdx.x * blockDim.x + threadIdx.x;
    if (row >= rows) return;

    float* r = data + row * cols;

    /* find max for numerical stability */
    float mx = r[0];
    for (int j = 1; j < cols; j++) if (r[j] > mx) mx = r[j];

    float sum = 0.0f;
    for (int j = 0; j < cols; j++) { r[j] = expf(r[j] - mx); sum += r[j]; }
    for (int j = 0; j < cols; j++) r[j] /= sum;
}

/* Add bias (no activation) */
__global__ void kernel_add_bias(float* data, float* bias, int rows, int cols) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < rows * cols) data[i] += bias[i % cols];
}

static int blocks(int n, int threads) { return (n + threads - 1) / threads; }

extern "C" void mocha_tensor_relu(MochaTensor* t) {
    if (!t->on_gpu) mocha_tensor_upload(t);
    int n = t->rows * t->cols;
    kernel_relu<<<blocks(n, 256), 256>>>(t->dev_data, n);
}

extern "C" void mocha_tensor_relu_bias(MochaTensor* t, MochaTensor* bias) {
    if (!t->on_gpu)    mocha_tensor_upload(t);
    if (!bias->on_gpu) mocha_tensor_upload(bias);
    int n = t->rows * t->cols;
    kernel_relu_bias<<<blocks(n, 256), 256>>>(t->dev_data, bias->dev_data, t->rows, t->cols);
}

extern "C" void mocha_tensor_sigmoid(MochaTensor* t) {
    if (!t->on_gpu) mocha_tensor_upload(t);
    int n = t->rows * t->cols;
    kernel_sigmoid<<<blocks(n, 256), 256>>>(t->dev_data, n);
}

extern "C" void mocha_tensor_tanh(MochaTensor* t) {
    if (!t->on_gpu) mocha_tensor_upload(t);
    int n = t->rows * t->cols;
    kernel_tanh_act<<<blocks(n, 256), 256>>>(t->dev_data, n);
}

extern "C" void mocha_tensor_softmax(MochaTensor* t) {
    if (!t->on_gpu) mocha_tensor_upload(t);
    kernel_softmax<<<blocks(t->rows, 256), 256>>>(t->dev_data, t->rows, t->cols);
}

extern "C" void mocha_tensor_add_bias(MochaTensor* t, MochaTensor* bias) {
    if (!t->on_gpu)    mocha_tensor_upload(t);
    if (!bias->on_gpu) mocha_tensor_upload(bias);
    int n = t->rows * t->cols;
    kernel_add_bias<<<blocks(n, 256), 256>>>(t->dev_data, bias->dev_data, t->rows, t->cols);
}

/* ── Element-wise ops ─────────────────────────────────────────────────────── */

__global__ void kernel_add(float* a, float* b, float* c, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) c[i] = a[i] + b[i];
}

__global__ void kernel_mul(float* a, float* b, float* c, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) c[i] = a[i] * b[i];
}

__global__ void kernel_scale(float* data, float scalar, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) data[i] *= scalar;
}

extern "C" MochaTensor* mocha_tensor_add(MochaTensor* a, MochaTensor* b) {
    if (!a->on_gpu) mocha_tensor_upload(a);
    if (!b->on_gpu) mocha_tensor_upload(b);
    MochaTensor* c = mocha_tensor_new(a->rows, a->cols);
    cudaMalloc((void**)&c->dev_data, a->rows * a->cols * sizeof(float));
    c->on_gpu = 1;
    int n = a->rows * a->cols;
    kernel_add<<<blocks(n, 256), 256>>>(a->dev_data, b->dev_data, c->dev_data, n);
    return c;
}

extern "C" MochaTensor* mocha_tensor_mul(MochaTensor* a, MochaTensor* b) {
    if (!a->on_gpu) mocha_tensor_upload(a);
    if (!b->on_gpu) mocha_tensor_upload(b);
    MochaTensor* c = mocha_tensor_new(a->rows, a->cols);
    cudaMalloc((void**)&c->dev_data, a->rows * a->cols * sizeof(float));
    c->on_gpu = 1;
    int n = a->rows * a->cols;
    kernel_mul<<<blocks(n, 256), 256>>>(a->dev_data, b->dev_data, c->dev_data, n);
    return c;
}

extern "C" void mocha_tensor_scale(MochaTensor* t, double scalar) {
    if (!t->on_gpu) mocha_tensor_upload(t);
    int n = t->rows * t->cols;
    kernel_scale<<<blocks(n, 256), 256>>>(t->dev_data, (float)scalar, n);
}

/* ── Transpose ────────────────────────────────────────────────────────────── */

__global__ void kernel_transpose(float* in, float* out, int rows, int cols) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int j = blockIdx.y * blockDim.y + threadIdx.y;
    if (i < rows && j < cols)
        out[j * rows + i] = in[i * cols + j];
}

extern "C" MochaTensor* mocha_tensor_transpose(MochaTensor* t) {
    if (!t->on_gpu) mocha_tensor_upload(t);
    MochaTensor* out = mocha_tensor_new(t->cols, t->rows);
    cudaMalloc((void**)&out->dev_data, t->rows * t->cols * sizeof(float));
    out->on_gpu = 1;
    dim3 threads(16, 16);
    dim3 grid(blocks(t->rows, 16), blocks(t->cols, 16));
    kernel_transpose<<<grid, threads>>>(t->dev_data, out->dev_data, t->rows, t->cols);
    return out;
}

/* ── Fill / zeros / ones ──────────────────────────────────────────────────── */

__global__ void kernel_fill(float* data, float val, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) data[i] = val;
}

extern "C" void mocha_tensor_fill(MochaTensor* t, double val) {
    if (!t->on_gpu) mocha_tensor_upload(t);
    int n = t->rows * t->cols;
    kernel_fill<<<blocks(n, 256), 256>>>(t->dev_data, (float)val, n);
}

extern "C" void mocha_tensor_zeros(MochaTensor* t) { mocha_tensor_fill(t, 0.0f); }
extern "C" void mocha_tensor_ones(MochaTensor* t)  { mocha_tensor_fill(t, 1.0f); }

/* ── Debug print ──────────────────────────────────────────────────────────── */

extern "C" void mocha_tensor_print(MochaTensor* t) {
    if (t->on_gpu) mocha_tensor_download(t);
    printf("Tensor [%d x %d]:\n", t->rows, t->cols);
    for (int i = 0; i < t->rows; i++) {
        printf("  [ ");
        for (int j = 0; j < t->cols; j++) {
            printf("%.4f ", t->host_data[i * t->cols + j]);
        }
        printf("]\n");
    }
}

/* ── Activation gradients ─────────────────────────────────────────────────── */

/* ReLU gradient: dInput = dOutput * (output > 0 ? 1 : 0) */
__global__ void kernel_relu_grad(float* dout, float* out, float* din, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) din[i] = dout[i] * (out[i] > 0.0f ? 1.0f : 0.0f);
}

/* Sigmoid gradient: dInput = dOutput * output * (1 - output) */
__global__ void kernel_sigmoid_grad(float* dout, float* out, float* din, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) din[i] = dout[i] * out[i] * (1.0f - out[i]);
}

/* Tanh gradient: dInput = dOutput * (1 - output^2) */
__global__ void kernel_tanh_grad(float* dout, float* out, float* din, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) din[i] = dout[i] * (1.0f - out[i] * out[i]);
}

/* Softmax + CrossEntropy gradient combined: dInput = output - labels */
__global__ void kernel_softmax_ce_grad(float* out, float* labels, float* din, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) din[i] = out[i] - labels[i];
}

/* Bias gradient: sum dOutput rows → dBias [1 x cols] */
__global__ void kernel_bias_grad(float* dout, float* dbias, int rows, int cols) {
    int j = blockIdx.x * blockDim.x + threadIdx.x;
    if (j >= cols) return;
    float sum = 0.0f;
    for (int i = 0; i < rows; i++) sum += dout[i * cols + j];
    dbias[j] = sum;
}

/* ── Loss functions ───────────────────────────────────────────────────────── */

/* MSE loss: mean of (output - labels)^2 */
__global__ void kernel_mse_loss(float* out, float* labels, float* loss, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) {
        float diff = out[i] - labels[i];
        atomicAdd(loss, diff * diff / n);
    }
}

/* MSE gradient: dOutput = 2 * (output - labels) / n */
__global__ void kernel_mse_grad(float* out, float* labels, float* dout, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) dout[i] = 2.0f * (out[i] - labels[i]) / n;
}

/* Cross-entropy loss: mean of -labels * log(output) */
__global__ void kernel_ce_loss(float* out, float* labels, float* loss, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) atomicAdd(loss, -labels[i] * logf(out[i] + 1e-8f) / n);
}

extern "C" MochaTensor* mocha_tensor_relu_grad(MochaTensor* dout, MochaTensor* out) {
    if (!dout->on_gpu) mocha_tensor_upload(dout);
    if (!out->on_gpu)  mocha_tensor_upload(out);
    MochaTensor* din = mocha_tensor_new(dout->rows, dout->cols);
    cudaMalloc((void**)&din->dev_data, dout->rows * dout->cols * sizeof(float));
    din->on_gpu = 1;
    int n = dout->rows * dout->cols;
    kernel_relu_grad<<<blocks(n, 256), 256>>>(dout->dev_data, out->dev_data, din->dev_data, n);
    return din;
}

extern "C" MochaTensor* mocha_tensor_sigmoid_grad(MochaTensor* dout, MochaTensor* out) {
    if (!dout->on_gpu) mocha_tensor_upload(dout);
    if (!out->on_gpu)  mocha_tensor_upload(out);
    MochaTensor* din = mocha_tensor_new(dout->rows, dout->cols);
    cudaMalloc((void**)&din->dev_data, dout->rows * dout->cols * sizeof(float));
    din->on_gpu = 1;
    int n = dout->rows * dout->cols;
    kernel_sigmoid_grad<<<blocks(n, 256), 256>>>(dout->dev_data, out->dev_data, din->dev_data, n);
    return din;
}

extern "C" MochaTensor* mocha_tensor_tanh_grad(MochaTensor* dout, MochaTensor* out) {
    if (!dout->on_gpu) mocha_tensor_upload(dout);
    if (!out->on_gpu)  mocha_tensor_upload(out);
    MochaTensor* din = mocha_tensor_new(dout->rows, dout->cols);
    cudaMalloc((void**)&din->dev_data, dout->rows * dout->cols * sizeof(float));
    din->on_gpu = 1;
    int n = dout->rows * dout->cols;
    kernel_tanh_grad<<<blocks(n, 256), 256>>>(dout->dev_data, out->dev_data, din->dev_data, n);
    return din;
}

extern "C" MochaTensor* mocha_tensor_softmax_ce_grad(MochaTensor* out, MochaTensor* labels) {
    if (!out->on_gpu)    mocha_tensor_upload(out);
    if (!labels->on_gpu) mocha_tensor_upload(labels);
    MochaTensor* din = mocha_tensor_new(out->rows, out->cols);
    cudaMalloc((void**)&din->dev_data, out->rows * out->cols * sizeof(float));
    din->on_gpu = 1;
    int n = out->rows * out->cols;
    kernel_softmax_ce_grad<<<blocks(n, 256), 256>>>(out->dev_data, labels->dev_data, din->dev_data, n);
    return din;
}

extern "C" MochaTensor* mocha_tensor_bias_grad(MochaTensor* dout) {
    if (!dout->on_gpu) mocha_tensor_upload(dout);
    MochaTensor* dbias = mocha_tensor_new(1, dout->cols);
    cudaMalloc((void**)&dbias->dev_data, dout->cols * sizeof(float));
    dbias->on_gpu = 1;
    cudaMemset(dbias->dev_data, 0, dout->cols * sizeof(float));
    kernel_bias_grad<<<blocks(dout->cols, 256), 256>>>(dout->dev_data, dbias->dev_data, dout->rows, dout->cols);
    return dbias;
}

extern "C" double mocha_tensor_mse_loss(MochaTensor* out, MochaTensor* labels) {
    if (!out->on_gpu)    mocha_tensor_upload(out);
    if (!labels->on_gpu) mocha_tensor_upload(labels);
    float* d_loss;
    cudaMalloc((void**)&d_loss, sizeof(float));
    cudaMemset(d_loss, 0, sizeof(float));
    int n = out->rows * out->cols;
    kernel_mse_loss<<<blocks(n, 256), 256>>>(out->dev_data, labels->dev_data, d_loss, n);
    float h_loss = 0.0f;
    cudaMemcpy(&h_loss, d_loss, sizeof(float), cudaMemcpyDeviceToHost);
    cudaFree(d_loss);
    return (double)h_loss;
}

extern "C" MochaTensor* mocha_tensor_mse_grad(MochaTensor* out, MochaTensor* labels) {
    if (!out->on_gpu)    mocha_tensor_upload(out);
    if (!labels->on_gpu) mocha_tensor_upload(labels);
    MochaTensor* dout = mocha_tensor_new(out->rows, out->cols);
    cudaMalloc((void**)&dout->dev_data, out->rows * out->cols * sizeof(float));
    dout->on_gpu = 1;
    int n = out->rows * out->cols;
    kernel_mse_grad<<<blocks(n, 256), 256>>>(out->dev_data, labels->dev_data, dout->dev_data, n);
    return dout;
}

extern "C" double mocha_tensor_ce_loss(MochaTensor* out, MochaTensor* labels) {
    if (!out->on_gpu)    mocha_tensor_upload(out);
    if (!labels->on_gpu) mocha_tensor_upload(labels);
    float* d_loss;
    cudaMalloc((void**)&d_loss, sizeof(float));
    cudaMemset(d_loss, 0, sizeof(float));
    int n = out->rows * out->cols;
    kernel_ce_loss<<<blocks(n, 256), 256>>>(out->dev_data, labels->dev_data, d_loss, n);
    float h_loss = 0.0f;
    cudaMemcpy(&h_loss, d_loss, sizeof(float), cudaMemcpyDeviceToHost);
    cudaFree(d_loss);
    return (double)h_loss;
}

/* ── Adam optimizer update ────────────────────────────────────────────────── */
/*
 * w  = w  - lr * m_hat / (sqrt(v_hat) + eps)
 * m  = beta1 * m  + (1 - beta1) * dw
 * v  = beta2 * v  + (1 - beta2) * dw^2
 * m_hat = m / (1 - beta1^t)
 * v_hat = v / (1 - beta2^t)
 */

__global__ void kernel_adam_update(
    float* w, float* m, float* v, float* dw,
    float lr, float beta1, float beta2, float eps,
    float beta1t, float beta2t, int n)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= n) return;

    m[i] = beta1 * m[i] + (1.0f - beta1) * dw[i];
    v[i] = beta2 * v[i] + (1.0f - beta2) * dw[i] * dw[i];

    float m_hat = m[i] / (1.0f - beta1t);
    float v_hat = v[i] / (1.0f - beta2t);

    w[i] -= lr * m_hat / (sqrtf(v_hat) + eps);
}

extern "C" void mocha_adam_update(
    MochaTensor* w, MochaTensor* m, MochaTensor* v, MochaTensor* dw,
    double lr, double beta1, double beta2, double eps,
    double beta1t, double beta2t)
{
    if (!w->on_gpu)  mocha_tensor_upload(w);
    if (!m->on_gpu)  mocha_tensor_upload(m);
    if (!v->on_gpu)  mocha_tensor_upload(v);
    if (!dw->on_gpu) mocha_tensor_upload(dw);

    int n = w->rows * w->cols;
    kernel_adam_update<<<blocks(n, 256), 256>>>(
        w->dev_data, m->dev_data, v->dev_data, dw->dev_data,
        (float)lr, (float)beta1, (float)beta2, (float)eps,
        (float)beta1t, (float)beta2t, n
    );
    w->on_gpu = 1;
}

/* ── Tensor concatenation (horizontal) ───────────────────────────────────── */
/*
 * Concatenates a and b column-wise: [a | b]
 * a: [rows x cols_a]   b: [rows x cols_b]
 * out: [rows x (cols_a + cols_b)]
 */

__global__ void kernel_concat(float* a, float* b, float* out,
                               int rows, int cols_a, int cols_b) {
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    int total_cols = cols_a + cols_b;
    if (row >= rows || col >= total_cols) return;
    if (col < cols_a)
        out[row * total_cols + col] = a[row * cols_a + col];
    else
        out[row * total_cols + col] = b[row * cols_b + (col - cols_a)];
}

extern "C" MochaTensor* mocha_tensor_concat(MochaTensor* a, MochaTensor* b) {
    if (!a->on_gpu) mocha_tensor_upload(a);
    if (!b->on_gpu) mocha_tensor_upload(b);

    int rows     = a->rows;
    int cols_a   = a->cols;
    int cols_b   = b->cols;
    int out_cols = cols_a + cols_b;

    MochaTensor* out = mocha_tensor_new(rows, out_cols);
    cudaMalloc((void**)&out->dev_data, rows * out_cols * sizeof(float));
    out->on_gpu = 1;

    dim3 threads(16, 16);
    dim3 grid(blocks(out_cols, 16), blocks(rows, 16));
    kernel_concat<<<grid, threads>>>(a->dev_data, b->dev_data, out->dev_data,
                                     rows, cols_a, cols_b);
    return out;
}

/* ── Element-wise multiply (Hadamard) ─────────────────────────────────────── */
/* Already have kernel_mul but need a non-destructive version returning new tensor */
/* mocha_tensor_mul already exists and returns new tensor — reuse that */

/* ── Element-wise: (1 - a) * b ────────────────────────────────────────────── */
/* Used in GRU: (1-z)*h_prev */
__global__ void kernel_one_minus_mul(float* a, float* b, float* out, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) out[i] = (1.0f - a[i]) * b[i];
}

extern "C" MochaTensor* mocha_tensor_one_minus_mul(MochaTensor* a, MochaTensor* b) {
    if (!a->on_gpu) mocha_tensor_upload(a);
    if (!b->on_gpu) mocha_tensor_upload(b);
    MochaTensor* out = mocha_tensor_new(a->rows, a->cols);
    cudaMalloc((void**)&out->dev_data, a->rows * a->cols * sizeof(float));
    out->on_gpu = 1;
    int n = a->rows * a->cols;
    kernel_one_minus_mul<<<blocks(n, 256), 256>>>(a->dev_data, b->dev_data, out->dev_data, n);
    return out;
}

/* ── Element-wise multiply returning new tensor ───────────────────────────── */
/* mocha_tensor_mul already exists — no new kernel needed */

/* ── GRU hidden state grad kernels ───────────────────────────────────────── */

/* d/d(sigmoid input): dgate = dout * gate * (1 - gate) */
/* reuse kernel_sigmoid_grad */

/* d/d(tanh input): dcand = dout * (1 - cand^2) */
/* reuse kernel_tanh_grad */

/* Split gradient: split [rows x (cols_a+cols_b)] back into two parts */
__global__ void kernel_split_a(float* grad, float* out_a,
                                int rows, int cols_a, int total_cols) {
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    if (row >= rows || col >= cols_a) return;
    out_a[row * cols_a + col] = grad[row * total_cols + col];
}

__global__ void kernel_split_b(float* grad, float* out_b,
                                int rows, int cols_b, int cols_a, int total_cols) {
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    if (row >= rows || col >= cols_b) return;
    out_b[row * cols_b + col] = grad[row * total_cols + col + cols_a];
}

extern "C" MochaTensor* mocha_tensor_split_a(MochaTensor* grad, int cols_a) {
    if (!grad->on_gpu) mocha_tensor_upload(grad);
    int rows       = grad->rows;
    int total_cols = grad->cols;
    MochaTensor* out = mocha_tensor_new(rows, cols_a);
    cudaMalloc((void**)&out->dev_data, rows * cols_a * sizeof(float));
    out->on_gpu = 1;
    dim3 threads(16, 16);
    dim3 grid(blocks(cols_a, 16), blocks(rows, 16));
    kernel_split_a<<<grid, threads>>>(grad->dev_data, out->dev_data,
                                      rows, cols_a, total_cols);
    return out;
}

extern "C" MochaTensor* mocha_tensor_split_b(MochaTensor* grad, int cols_a) {
    if (!grad->on_gpu) mocha_tensor_upload(grad);
    int rows       = grad->rows;
    int total_cols = grad->cols;
    int cols_b     = total_cols - cols_a;
    MochaTensor* out = mocha_tensor_new(rows, cols_b);
    cudaMalloc((void**)&out->dev_data, rows * cols_b * sizeof(float));
    out->on_gpu = 1;
    dim3 threads(16, 16);
    dim3 grid(blocks(cols_b, 16), blocks(rows, 16));
    kernel_split_b<<<grid, threads>>>(grad->dev_data, out->dev_data,
                                      rows, cols_b, cols_a, total_cols);
    return out;
}

/* ── Row-wise sum (for bias grad in GRU) ─────────────────────────────────── */
/* reuse mocha_tensor_bias_grad — already does column sum */

extern "C" MochaTensor* mocha_tensor_clone(MochaTensor* t) {
    if (!t->on_gpu) mocha_tensor_upload(t);
    MochaTensor* out = mocha_tensor_new(t->rows, t->cols);
    cudaMalloc((void**)&out->dev_data, t->rows * t->cols * sizeof(float));
    cudaMemcpy(out->dev_data, t->dev_data, t->rows * t->cols * sizeof(float), cudaMemcpyDeviceToDevice);
    out->on_gpu = 1;
    return out;
}

/* ── Hopfield network kernels ─────────────────────────────────────────────── */

/* Sign function: +1 if x > 0, -1 if x <= 0 */
__global__ void kernel_sign(float* data, float* out, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) out[i] = (data[i] > 0.0f) ? 1.0f : -1.0f;
}

/* Outer product: out = a^T * b
 * a: [1 x n]  b: [1 x n]  out: [n x n]
 */
__global__ void kernel_outer(float* a, float* b, float* out, int n) {
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    if (row < n && col < n)
        out[row * n + col] = a[row] * b[col];
}

/* Zero diagonal of a square matrix */
__global__ void kernel_zero_diagonal(float* data, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) data[i * n + i] = 0.0f;
}

/* Add two matrices in place: a += b */
__global__ void kernel_add_inplace(float* a, float* b, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) a[i] += b[i];
}

/* Scale in place: a *= scalar */
__global__ void kernel_scale_inplace(float* data, float scalar, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) data[i] *= scalar;
}

/* Check convergence: returns 1 if a == b element-wise, 0 otherwise */
__global__ void kernel_equal(float* a, float* b, int* result, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n && a[i] != b[i])
        atomicAnd(result, 0);
}

extern "C" MochaTensor* mocha_tensor_sign(MochaTensor* t) {
    if (!t->on_gpu) mocha_tensor_upload(t);
    MochaTensor* out = mocha_tensor_new(t->rows, t->cols);
    cudaMalloc((void**)&out->dev_data, t->rows * t->cols * sizeof(float));
    out->on_gpu = 1;
    int n = t->rows * t->cols;
    kernel_sign<<<blocks(n, 256), 256>>>(t->dev_data, out->dev_data, n);
    return out;
}

extern "C" MochaTensor* mocha_tensor_outer(MochaTensor* a, MochaTensor* b) {
    // a and b are [1 x n] row vectors
    if (!a->on_gpu) mocha_tensor_upload(a);
    if (!b->on_gpu) mocha_tensor_upload(b);
    int n = a->cols;
    MochaTensor* out = mocha_tensor_new(n, n);
    cudaMalloc((void**)&out->dev_data, n * n * sizeof(float));
    out->on_gpu = 1;
    dim3 threads(16, 16);
    dim3 grid(blocks(n, 16), blocks(n, 16));
    kernel_outer<<<grid, threads>>>(a->dev_data, b->dev_data, out->dev_data, n);
    return out;
}

extern "C" void mocha_tensor_zero_diagonal(MochaTensor* t) {
    if (!t->on_gpu) mocha_tensor_upload(t);
    int n = t->rows;
    kernel_zero_diagonal<<<blocks(n, 256), 256>>>(t->dev_data, n);
}

extern "C" void mocha_tensor_add_inplace(MochaTensor* a, MochaTensor* b) {
    if (!a->on_gpu) mocha_tensor_upload(a);
    if (!b->on_gpu) mocha_tensor_upload(b);
    int n = a->rows * a->cols;
    kernel_add_inplace<<<blocks(n, 256), 256>>>(a->dev_data, b->dev_data, n);
}

extern "C" int mocha_tensor_equal(MochaTensor* a, MochaTensor* b) {
    if (!a->on_gpu) mocha_tensor_upload(a);
    if (!b->on_gpu) mocha_tensor_upload(b);
    int* d_result;
    cudaMalloc((void**)&d_result, sizeof(int));
    int h_result = 1;
    cudaMemcpy(d_result, &h_result, sizeof(int), cudaMemcpyHostToDevice);
    int n = a->rows * a->cols;
    kernel_equal<<<blocks(n, 256), 256>>>(a->dev_data, b->dev_data, d_result, n);
    cudaMemcpy(&h_result, d_result, sizeof(int), cudaMemcpyDeviceToHost);
    cudaFree(d_result);
    return h_result;
}

/* ── Layer Normalization ──────────────────────────────────────────────────── */
/*
 * Normalizes each row independently:
 * y = (x - mean) / sqrt(var + eps) * gamma + beta
 * gamma and beta are learnable per-feature scalars
 */

__global__ void kernel_layer_norm(float* x, float* gamma, float* beta,
                                   float* out, int rows, int cols, float eps) {
    int row = blockIdx.x * blockDim.x + threadIdx.x;
    if (row >= rows) return;

    float* xr = x + row * cols;
    float* yr = out + row * cols;

    // compute mean
    float mean = 0.0f;
    for (int j = 0; j < cols; j++) mean += xr[j];
    mean /= cols;

    // compute variance
    float var = 0.0f;
    for (int j = 0; j < cols; j++) {
        float d = xr[j] - mean;
        var += d * d;
    };
    var /= cols;

    // normalize
    float std = sqrtf(var + eps);
    for (int j = 0; j < cols; j++) {
        yr[j] = ((xr[j] - mean) / std) * gamma[j] + beta[j];
    };
}

/* Layer norm backward */
__global__ void kernel_layer_norm_grad(float* dout, float* x, float* gamma,
                                        float* dx, float* dgamma, float* dbeta,
                                        int rows, int cols, float eps) {
    int row = blockIdx.x * blockDim.x + threadIdx.x;
    if (row >= rows) return;

    float* xr    = x    + row * cols;
    float* doutr = dout + row * cols;
    float* dxr   = dx   + row * cols;

    float mean = 0.0f;
    for (int j = 0; j < cols; j++) mean += xr[j];
    mean /= cols;

    float var = 0.0f;
    for (int j = 0; j < cols; j++) {
        float d = xr[j] - mean;
        var += d * d;
    };
    var /= cols;
    float std = sqrtf(var + eps);

    float dstd = 0.0f;
    float dmean = 0.0f;
    for (int j = 0; j < cols; j++) {
        float xhat = (xr[j] - mean) / std;
        atomicAdd(&dgamma[j], doutr[j] * xhat);
        atomicAdd(&dbeta[j],  doutr[j]);
        dstd  += doutr[j] * gamma[j] * (xr[j] - mean);
        dmean += doutr[j] * gamma[j];
    };
    dstd  = dstd  * (-1.0f / (std * std));
    dmean = dmean * (-1.0f / std);

    for (int j = 0; j < cols; j++) {
        dxr[j] = doutr[j] * gamma[j] / std
               + dstd  * 2.0f * (xr[j] - mean) / cols
               + dmean / cols;
    };
}

extern "C" MochaTensor* mocha_layer_norm(MochaTensor* x, MochaTensor* gamma,
                                          MochaTensor* beta, double eps) {
    if (!x->on_gpu)     mocha_tensor_upload(x);
    if (!gamma->on_gpu) mocha_tensor_upload(gamma);
    if (!beta->on_gpu)  mocha_tensor_upload(beta);

    MochaTensor* out = mocha_tensor_new(x->rows, x->cols);
    cudaMalloc((void**)&out->dev_data, x->rows * x->cols * sizeof(float));
    out->on_gpu = 1;

    kernel_layer_norm<<<blocks(x->rows, 256), 256>>>(
        x->dev_data, gamma->dev_data, beta->dev_data,
        out->dev_data, x->rows, x->cols, (float)eps
    );
    return out;
}

extern "C" void mocha_layer_norm_grad(MochaTensor* dout, MochaTensor* x,
                                       MochaTensor* gamma, MochaTensor* dx,
                                       MochaTensor* dgamma, MochaTensor* dbeta,
                                       double eps) {
    if (!dout->on_gpu)   mocha_tensor_upload(dout);
    if (!x->on_gpu)      mocha_tensor_upload(x);
    if (!gamma->on_gpu)  mocha_tensor_upload(gamma);
    if (!dx->on_gpu)     mocha_tensor_upload(dx);
    if (!dgamma->on_gpu) mocha_tensor_upload(dgamma);
    if (!dbeta->on_gpu)  mocha_tensor_upload(dbeta);

    // explicitly zero dgamma and dbeta before atomicAdd accumulation
    cudaMemset(dgamma->dev_data, 0, dgamma->cols * sizeof(float));
    cudaMemset(dbeta->dev_data,  0, dbeta->cols  * sizeof(float));
    cudaMemset(dx->dev_data,     0, x->rows * x->cols * sizeof(float));

    kernel_layer_norm_grad<<<blocks(x->rows, 256), 256>>>(
        dout->dev_data, x->dev_data, gamma->dev_data,
        dx->dev_data, dgamma->dev_data, dbeta->dev_data,
        x->rows, x->cols, (float)eps
    );
    
    // sync to ensure kernel completes before returning
    cudaDeviceSynchronize();
}

/* ── Liquid State Machine kernels ────────────────────────────────────────── */

/* Element-wise tanh activation (in-place) — already have kernel_tanh_act */

/* Matrix-vector multiply: out = A @ v
 * A: [rows x cols]  v: [cols x 1]  out: [rows x 1]
 * Used for power iteration
 */
__global__ void kernel_matvec(float* A, float* v, float* out, int rows, int cols) {
    int row = blockIdx.x * blockDim.x + threadIdx.x;
    if (row >= rows) return;
    float sum = 0.0f;
    for (int j = 0; j < cols; j++)
        sum += A[row * cols + j] * v[j];
    out[row] = sum;
}

/* Vector norm: returns sqrt(sum of squares) */
__global__ void kernel_dot(float* a, float* b, float* result, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) atomicAdd(result, a[i] * b[i]);
}

/* Scale vector: v = v / scalar */
__global__ void kernel_scale_vec(float* v, float scalar, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) v[i] /= scalar;
}

__global__ void kernel_xtx_plus_lambda(float* XtX, float lambda, int d) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < d) XtX[i * d + i] += lambda;
}

/* Conjugate gradient step kernels */
__global__ void kernel_axpy(float* y, float alpha, float* x, int n) {
    // y = y + alpha * x
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) y[i] += alpha * x[i];
}

__global__ void kernel_copy(float* dst, float* src, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) dst[i] = src[i];
}

__global__ void kernel_xpay(float* x, float alpha, float* y, int n) {
    // x = y + alpha * x  (note: overwrites x)
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) x[i] = y[i] + alpha * x[i];
}

/* Power iteration to find spectral radius of W [n x n]
 * Returns largest eigenvalue magnitude
 * Modifies W in place by scaling to target spectral radius
 */
extern "C" void mocha_lsm_scale_reservoir(MochaTensor* W, double target_sr) {
    if (!W->on_gpu) mocha_tensor_upload(W);
    int n = W->rows;

    float* d_v;    cudaMalloc((void**)&d_v,    n * sizeof(float));
    float* d_vnew; cudaMalloc((void**)&d_vnew, n * sizeof(float));
    float* d_dot;  cudaMalloc((void**)&d_dot,  sizeof(float));

    float init_val = 1.0f / sqrtf((float)n);
    for (int i = 0; i < n; i++)
        cudaMemcpy(d_v + i, &init_val, sizeof(float), cudaMemcpyHostToDevice);

    float eigenvalue = 1.0f;

    for (int iter = 0; iter < 50; iter++) {
        kernel_matvec<<<blocks(n, 256), 256>>>(W->dev_data, d_v, d_vnew, n, n);

        // FIX 1: use ||v_new|| as eigenvalue estimate
        float h_dot = 0.0f;
        cudaMemcpy(d_dot, &h_dot, sizeof(float), cudaMemcpyHostToDevice);
        kernel_dot<<<blocks(n, 256), 256>>>(d_vnew, d_vnew, d_dot, n);
        cudaMemcpy(&eigenvalue, d_dot, sizeof(float), cudaMemcpyDeviceToHost);
        eigenvalue = sqrtf(eigenvalue);
        if (eigenvalue < 1e-10f) eigenvalue = 1e-10f;

        kernel_scale_vec<<<blocks(n, 256), 256>>>(d_vnew, eigenvalue, n);

        float* tmp = d_v; d_v = d_vnew; d_vnew = tmp;
    }

    float scale = (float)target_sr / eigenvalue;
    kernel_scale<<<blocks(n * n, 256), 256>>>(W->dev_data, scale, n * n);

    cudaFree(d_v);
    cudaFree(d_vnew);
    cudaFree(d_dot);
}

__global__ void kernel_xtx(float* X, float* XtX, int n, int d) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= d * d) return;
    int i = idx / d;
    int j = idx % d;
    float sum = 0.0f;
    for (int k = 0; k < n; k++)
        sum += X[k * d + i] * X[k * d + j];
    XtX[i * d + j] = sum;
}

__global__ void kernel_xty(float* X, float* y, float* Xty, int n, int d) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= d) return;
    float sum = 0.0f;
    for (int k = 0; k < n; k++)
        sum += X[k * d + i] * y[k];
    Xty[i] = sum;
}

/* Ridge regression: solve w = (X^T X + lambda*I)^-1 X^T y
 * using conjugate gradient
 * X: [n x d]  y: [n x 1]  returns w: [d x 1]
 */
extern "C" MochaTensor* mocha_ridge_regression(MochaTensor* X, MochaTensor* y,
                                                double lambda, int max_iter) {
    if (!X->on_gpu) mocha_tensor_upload(X);
    if (!y->on_gpu) mocha_tensor_upload(y);

    int n = X->rows;
    int d = X->cols;

    // FIX 2: correct cublasSgemm for row-major X^T X
    float* d_XtX;
    cudaMalloc((void**)&d_XtX, d * d * sizeof(float));
    float alpha = 1.0f, beta = 0.0f;
    /*
    cublasSgemm(g_cublas, CUBLAS_OP_T, CUBLAS_OP_N,
                d, d, n, &alpha,
                X->dev_data, n,
                X->dev_data, n,
                &beta, d_XtX, d);
    */
   cudaMemset(d_XtX, 0, d * d * sizeof(float));
    kernel_xtx<<<blocks(d * d, 256), 256>>>(X->dev_data, d_XtX, n, d);
    kernel_xtx_plus_lambda<<<blocks(d, 256), 256>>>(d_XtX, (float)lambda, d);

    // Xty = X^T @ y (original cublasSgemv)
    float* d_Xty;
    cudaMalloc((void**)&d_Xty, d * sizeof(float));
    /*cublasSgemv(g_cublas, CUBLAS_OP_T,
                n, d, &alpha,
                X->dev_data, n,
                y->dev_data, 1,
                &beta, d_Xty, 1);*/
    cudaMemset(d_Xty, 0, d * sizeof(float));
    kernel_xty<<<blocks(d, 256), 256>>>(X->dev_data, y->dev_data, d_Xty, n, d);
    float* d_w;   cudaMalloc((void**)&d_w,   d * sizeof(float));
    float* d_r;   cudaMalloc((void**)&d_r,   d * sizeof(float));
    float* d_p;   cudaMalloc((void**)&d_p,   d * sizeof(float));
    float* d_Ap;  cudaMalloc((void**)&d_Ap,  d * sizeof(float));
    float* d_dot; cudaMalloc((void**)&d_dot, sizeof(float));

    cudaMemset(d_w, 0, d * sizeof(float));
    cudaMemcpy(d_r, d_Xty, d * sizeof(float), cudaMemcpyDeviceToDevice);
    cudaMemcpy(d_p, d_Xty, d * sizeof(float), cudaMemcpyDeviceToDevice);

    for (int iter = 0; iter < max_iter; iter++) {
        kernel_matvec<<<blocks(d, 256), 256>>>(d_XtX, d_p, d_Ap, d, d);

        float rtr = 0.0f;
        cudaMemcpy(d_dot, &rtr, sizeof(float), cudaMemcpyHostToDevice);
        kernel_dot<<<blocks(d, 256), 256>>>(d_r, d_r, d_dot, d);
        cudaMemcpy(&rtr, d_dot, sizeof(float), cudaMemcpyDeviceToHost);

        float pAp = 0.0f;
        cudaMemcpy(d_dot, &pAp, sizeof(float), cudaMemcpyHostToDevice);
        kernel_dot<<<blocks(d, 256), 256>>>(d_p, d_Ap, d_dot, d);
        cudaMemcpy(&pAp, d_dot, sizeof(float), cudaMemcpyDeviceToHost);

        if (pAp < 1e-10f) break;
        float cg_alpha = rtr / pAp;

        kernel_axpy<<<blocks(d, 256), 256>>>(d_w, cg_alpha, d_p, d);
        kernel_axpy<<<blocks(d, 256), 256>>>(d_r, -cg_alpha, d_Ap, d);

        float rtr_new = 0.0f;
        cudaMemcpy(d_dot, &rtr_new, sizeof(float), cudaMemcpyHostToDevice);
        kernel_dot<<<blocks(d, 256), 256>>>(d_r, d_r, d_dot, d);
        cudaMemcpy(&rtr_new, d_dot, sizeof(float), cudaMemcpyDeviceToHost);

        if (rtr < 1e-10f) break;
        float cg_beta = rtr_new / rtr;

        kernel_xpay<<<blocks(d, 256), 256>>>(d_p, cg_beta, d_r, d);
    }

    MochaTensor* w = mocha_tensor_new(d, 1);
    if (!w->on_gpu) mocha_tensor_upload(w);
    cudaMemcpy(w->dev_data, d_w, d * sizeof(float), cudaMemcpyDeviceToDevice);
    w->on_gpu = 1;

    cudaFree(d_XtX); cudaFree(d_Xty);
    cudaFree(d_w);   cudaFree(d_r);
    cudaFree(d_p);   cudaFree(d_Ap);
    cudaFree(d_dot);

    return w;
}