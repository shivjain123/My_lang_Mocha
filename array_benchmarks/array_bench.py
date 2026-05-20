# array_bench.py
# Identical operations to Mocha array benchmark

# =====================================================
# BENCHMARK 1: Integer array sum (100,000 elements)
# =====================================================
size = 100000
arr = list(range(1, size + 1))

total = 0
for i in range(size):
    total += arr[i]
print(total)

# =====================================================
# BENCHMARK 2: Array reverse (100,000 elements)
# =====================================================
arr2 = list(range(size))

left = 0
right = size - 1
while left < right:
    arr2[left], arr2[right] = arr2[right], arr2[left]
    left += 1
    right -= 1
print(arr2[0])

# =====================================================
# BENCHMARK 3: Bubble sort (10,000 elements)
# =====================================================
ssize = 10000
sarr = list(range(ssize, 0, -1))

for outer in range(ssize - 1):
    for inner in range(ssize - outer - 1):
        if sarr[inner] > sarr[inner + 1]:
            sarr[inner], sarr[inner + 1] = sarr[inner + 1], sarr[inner]
print(sarr[0])

# =====================================================
# BENCHMARK 4: Linear search (10,000 searches)
# =====================================================
found = 0
for s in range(10000):
    target = s
    pos = -1
    for p in range(size):
        if arr[p] == target:
            pos = p
            break
    if pos != -1:
        found += 1
print(found)

# =====================================================
# BENCHMARK 5: Matrix multiply (100x100)
# =====================================================
dim = 100
matA = [[r + c for c in range(dim)] for r in range(dim)]
matB = [[r - c for c in range(dim)] for r in range(dim)]
matC = [[0] * dim for _ in range(dim)]

for row in range(dim):
    for col in range(dim):
        for k in range(dim):
            matC[row][col] += matA[row][k] * matB[k][col]
print(matC[0][0])
