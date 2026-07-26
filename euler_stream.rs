use std::time::Instant;
use std::collections::HashSet;

// ============================================================
// 1. PRIME SET
// ============================================================
const PRIMES: [u64; 11] = [7, 17, 19, 23, 29, 31, 37, 41, 43, 47, 59];

fn is_obstruction(S: u64, p: u64) -> bool {
    let S_mod = S % p;
    if S_mod == 0 { return false; }
    let exp = (p - 1) / 2;
    let result = mod_pow(S_mod, exp, p);
    result != 1
}

fn mod_pow(mut base: u64, mut exp: u64, modulus: u64) -> u64 {
    let mut result = 1;
    base %= modulus;
    while exp > 0 {
        if exp % 2 == 1 { result = (result * base) % modulus; }
        base = (base * base) % modulus;
        exp /= 2;
    }
    result
}

fn gcd(mut a: u64, mut b: u64) -> u64 {
    while b != 0 { let t = b; b = a % b; a = t; }
    a
}

// ============================================================
// 2. GENERATE ALL PYTHAGOREAN PAIRS (SORTED VECTOR)
// ============================================================
fn generate_pairs(max_leg: u64) -> Vec<(u64, u64)> {
    let m_limit = (max_leg as f64).sqrt() as u64 + 1;
    let mut pairs = Vec::new();

    for m in 2..=m_limit {
        for n in 1..m {
            if (m - n) % 2 == 0 { continue; }
            if gcd(m, n) != 1 { continue; }

            let a0 = m * m - n * n;
            let b0 = 2 * m * n;

            let mut k = 1u64;
            while k * a0 <= max_leg && k * b0 <= max_leg {
                let a = k * a0;
                let b = k * b0;
                if a <= b {
                    pairs.push((a, b));
                } else {
                    pairs.push((b, a));
                }
                k += 1;
            }
        }
    }

    pairs.sort_unstable();
    pairs
}

// ============================================================
// 3. SEARCH FOR PRIMITIVE EULER BRICKS
// ============================================================
fn main() {
    let start = Instant::now();
    let max_leg: u64 = 50_000_000;

    println!("========================================");
    println!("EULER BRICK SEARCH (PRIMITIVE ONLY)");
    println!("max_leg = {}", max_leg);
    println!("========================================\n");

    // Step 1: Generate all Pythagorean pairs
    println!("Generating Pythagorean pairs...");
    let pairs = generate_pairs(max_leg);
    println!("Total pairs: {}", pairs.len());

    // Step 2: Build a HashSet for O(1) lookup
    println!("Building lookup set...");
    let pair_set: HashSet<(u64, u64)> = pairs.iter().cloned().collect();
    println!("Lookup set built.");

    // Step 3: Build index of pairs by first element
    println!("Building index by first element...");
    let mut pairs_by_a: Vec<Vec<(u64, u64)>> = vec![Vec::new(); (max_leg + 1) as usize];
    for (a, b) in &pairs {
        if *a <= max_leg {
            pairs_by_a[*a as usize].push((*a, *b));
        }
    }
    println!("Index built.");

    // Step 4: Find PRIMITIVE Euler bricks
    println!("Searching for primitive Euler bricks...");
    let mut total_bricks = 0u64;
    let mut survivors: Vec<(u64, u64, u64, u64)> = Vec::new();

    for (a, b) in &pairs {
        if *a > max_leg { continue; }
        for (_, c) in &pairs_by_a[*a as usize] {
            if *c <= *b { continue; }
            if pair_set.contains(&(*b, *c)) || pair_set.contains(&(*c, *b)) {
                // Check if primitive
                if gcd(gcd(*a, *b), *c) == 1 {
                    total_bricks += 1;
                    let S = a * a + b * b + c * c;
                    let mut obstructed = false;
                    for &p in &PRIMES {
                        if is_obstruction(S, p) {
                            obstructed = true;
                            break;
                        }
                    }
                    if !obstructed {
                        survivors.push((*a, *b, *c, S));
                    }
                    if total_bricks % 100 == 0 {
                        println!("Found {} primitive bricks so far...", total_bricks);
                    }
                }
            }
        }
    }

    println!("\n========================================");
    println!("RESULTS");
    println!("========================================");
    println!("Total primitive Euler bricks: {}", total_bricks);
    println!("Survivors (pass ALL primes): {}", survivors.len());

    if survivors.is_empty() {
        println!("🎉 NO BRICKS SURVIVE THE MODULAR SIEVE!");
        println!("   The sieve is COMPLETE up to {}!", max_leg);
    } else {
        println!("⚠️ SURVIVORS FOUND:");
        for (a, b, c, S) in &survivors {
            println!("  ({}, {}, {})", a, b, c);
            println!("    S = {}", S);
            for &p in &PRIMES {
                println!("    S mod {} = {}", p, S % p);
            }
        }
    }

    println!("\nTime: {:?}", start.elapsed());
}