// array_bench.js
// Identical operations to Mocha array benchmark

// =====================================================
// BENCHMARK 1: Integer array sum (100,000 elements)
// =====================================================
const size = 100000;
const arr = new Array(size);
for (let idx = 0; idx < size; idx++) {
    arr[idx] = idx + 1;
}

let sum = 0n;  // BigInt to match vast behaviour
for (let i = 0; i < size; i++) {
    sum += BigInt(arr[i]);
}
console.log(sum.toString());

// =====================================================
// BENCHMARK 2: Array reverse (100,000 elements)
// =====================================================
const arr2 = new Array(size);
for (let a = 0; a < size; a++) {
    arr2[a] = a;
}

let left = 0;
let right = size - 1;
while (left < right) {
    const tmp = arr2[left];
    arr2[left] = arr2[right];
    arr2[right] = tmp;
    left++;
    right--;
}
console.log(arr2[0]);

// =====================================================
// BENCHMARK 3: Bubble sort (10,000 elements)
// =====================================================
const ssize = 10000;
const sarr = new Array(ssize);
for (let b = 0; b < ssize; b++) {
    sarr[b] = ssize - b;
}

for (let outer = 0; outer < ssize - 1; outer++) {
    for (let inner = 0; inner < ssize - outer - 1; inner++) {
        if (sarr[inner] > sarr[inner + 1]) {
            const t = sarr[inner];
            sarr[inner] = sarr[inner + 1];
            sarr[inner + 1] = t;
        }
    }
}
console.log(sarr[0]);

// =====================================================
// BENCHMARK 4: Linear search (10,000 searches)
// =====================================================
let found = 0;
for (let s = 0; s < 10000; s++) {
    const target = s;
    let pos = -1;
    for (let p = 0; p < size; p++) {
        if (arr[p] === target) {
            pos = p;
            break;
        }
    }
    if (pos !== -1) found++;
}
console.log(found);

// =====================================================
// BENCHMARK 5: Matrix multiply (100x100)
// =====================================================
const dim = 100;
const matA = Array.from({length: dim}, (_, r) =>
    Array.from({length: dim}, (_, c) => r + c));
const matB = Array.from({length: dim}, (_, r) =>
    Array.from({length: dim}, (_, c) => r - c));
const matC = Array.from({length: dim}, () => new Array(dim).fill(0));

for (let row = 0; row < dim; row++) {
    for (let col = 0; col < dim; col++) {
        for (let k = 0; k < dim; k++) {
            matC[row][col] += matA[row][k] * matB[k][col];
        }
    }
}
console.log(matC[0][0]);
