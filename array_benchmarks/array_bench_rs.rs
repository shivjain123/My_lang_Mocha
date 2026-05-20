// array_bench.rs
// Identical operations to Mocha array benchmark
// Compile: rustc -O array_bench.rs -o array_bench_rust

fn main() {

    // =====================================================
    // BENCHMARK 1: Integer array sum (100,000 elements)
    // =====================================================
    let size: usize = 100000;
    let arr: Vec<i64> = (1..=size as i64).collect();

    let mut sum: i64 = 0;
    for i in 0..size {
        sum += arr[i];
    }
    println!("{}", sum);

    // =====================================================
    // BENCHMARK 2: Array reverse (100,000 elements)
    // =====================================================
    let mut arr2: Vec<i64> = (0..size as i64).collect();

    let mut left: usize = 0;
    let mut right: usize = size - 1;
    while left < right {
        arr2.swap(left, right);
        left += 1;
        right -= 1;
    }
    println!("{}", arr2[0]);

    // =====================================================
    // BENCHMARK 3: Bubble sort (10,000 elements)
    // =====================================================
    let ssize: usize = 10000;
    let mut sarr: Vec<i64> = (1..=ssize as i64).rev().collect();

    for outer in 0..ssize - 1 {
        for inner in 0..ssize - outer - 1 {
            if sarr[inner] > sarr[inner + 1] {
                sarr.swap(inner, inner + 1);
            }
        }
    }
    println!("{}", sarr[0]);

    // =====================================================
    // BENCHMARK 4: Linear search (10,000 searches)
    // =====================================================
    let mut found: i64 = 0;
    for s in 0..10000_i64 {
        let target = s;
        let mut pos: i64 = -1;
        for p in 0..size {
            if arr[p] == target {
                pos = p as i64;
                break;
            }
        }
        if pos != -1 {
            found += 1;
        }
    }
    println!("{}", found);

    // =====================================================
    // BENCHMARK 5: Matrix multiply (100x100)
    // =====================================================
    let dim: usize = 100;
    let mut mat_a = vec![vec![0i64; dim]; dim];
    let mut mat_b = vec![vec![0i64; dim]; dim];
    let mut mat_c = vec![vec![0i64; dim]; dim];

    for r in 0..dim {
        for c in 0..dim {
            mat_a[r][c] = (r + c) as i64;
            mat_b[r][c] = (r as i64) - (c as i64);
        }
    }

    for row in 0..dim {
        for col in 0..dim {
            for k in 0..dim {
                mat_c[row][col] += mat_a[row][k] * mat_b[k][col];
            }
        }
    }
    println!("{}", mat_c[0][0]);
}
