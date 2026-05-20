// array_bench.mch
// Array benchmark for Mocha v0.5
// Tests: sum, reverse, sort, search, matrix multiply

function test(didLoad) -> null {

    // =====================================================
    // BENCHMARK 1: Integer array sum (100,000 elements)
    // =====================================================

    var size: int = 100000;
    var arr: int[] = alloc int[size];
    var idx: int = 0;
    while (idx < size) {
        arr[idx] = idx + 1;
        idx++;
    };

    var sum: vast = 0;   // ← vast for accumulation
    var i: int = 0;      // ← int for indexing
    while (i < size) {
        sum = sum + arr[i];
        i++;
    };
    print(str(sum), newLine=true);

    // =====================================================
    // BENCHMARK 2: Array reverse (100,000 elements)
    // =====================================================
    var arr2: int[] = alloc int[size];
    var a: int = 0;
    while (a < size) {
        arr2[a] = a;
        a++;
    };

    var left: int = 0;
    var right: int = size - 1;
    while (left < right) {
        var tmp: int = arr2[left];
        arr2[left] = arr2[right];
        arr2[right] = tmp;
        left++;
        right--;
    };
    print(str(arr2[0]), newLine=true);

    // =====================================================
    // BENCHMARK 3: Bubble sort (10,000 elements)
    // =====================================================
    var ssize: int = 10000;
    var sarr: int[] = alloc int[ssize];
    var b: int = 0;
    while (b < ssize) {
        sarr[b] = ssize - b;
        b++;
    };

    var outer: int = 0;
    while (outer < ssize - 1) {
        var inner: int = 0;
        while (inner < ssize - outer - 1) {
            if (sarr[inner] > sarr[inner + 1]) {
                var t: int = sarr[inner];
                sarr[inner] = sarr[inner + 1];
                sarr[inner + 1] = t;
            };
            inner++;
        };
        outer++;
    };
    print(str(sarr[0]), newLine=true);

    // =====================================================
    // BENCHMARK 4: Linear search (10,000 searches)
    // =====================================================
    var found: int = 0;
    var s: int = 0;
    while (s < 10000) {
        var target: int = s;
        var pos: int = -1;
        var p: int = 0;
        while (p < size) {
            if (arr[p] == target) {
                pos = p;
                p = size;
            };
            p++;
        };
        if (pos != -1) {
            found = found + 1;
        };
        s++;
    };
    print(str(found), newLine=true);

    // =====================================================
    // BENCHMARK 5: Matrix multiply (100x100)
    // =====================================================
    var dim: int = 100;
    var matA: int[][] = alloc int[dim][dim];
    var matB: int[][] = alloc int[dim][dim];
    var matC: int[][] = alloc int[dim][dim];

    var r: int = 0;
    while (r < dim) {
        var c: int = 0;
        while (c < dim) {
            matA[r][c] = r + c;
            matB[r][c] = r - c;
            matC[r][c] = 0;
            c++;
        };
        r++;
    };

    var row: int = 0;
    while (row < dim) {
        var col: int = 0;
        while (col < dim) {
            var k: int = 0;
            while (k < dim) {
                matC[row][col] = matC[row][col] + matA[row][k] * matB[k][col];
                k++;
            };
            col++;
        };
        row++;
    };
    print(str(matC[0][0]), newLine=true);

};