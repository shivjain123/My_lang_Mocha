fn main() {
    // Benchmark 1: String concatenation loop
    let mut result = String::new();
    for _ in 0..10000 {
        result.push_str("a");
    }
    println!("{}", result.len());

    // Benchmark 2: String contains
    let haystack = "the quick brown fox jumps over the lazy dog";
    let mut found = 0;
    for _ in 0..10000 {
        if haystack.contains("fox") {
            found += 1;
        }
    }
    println!("{}", found);

    // Benchmark 3: String reverse
    let s = "Hello Mocha World";
    let mut reversed = String::new();
    for _ in 0..10000 {
        reversed = s.chars().rev().collect::<String>();
    }
    println!("{}", reversed);

    // Benchmark 4: Split
    let csv = "one,two,three,four,five";
    let mut count = 0;
    for _ in 0..10000 {
        let parts: Vec<&str> = csv.split(',').collect();
        count += parts.len();
    }
    println!("{}", count);
}
