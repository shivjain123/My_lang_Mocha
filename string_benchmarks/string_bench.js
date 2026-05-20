// String benchmark - JavaScript (Node.js)

// Benchmark 1: String concatenation loop
let result = "";
for (let i = 0; i < 10000; i++) {
    result += "a";
}
console.log(result.length);

// Benchmark 2: String contains
const haystack = "the quick brown fox jumps over the lazy dog";
let found = 0;
for (let j = 0; j < 10000; j++) {
    if (haystack.includes("fox")) {
        found++;
    }
}
console.log(found);

// Benchmark 3: String reverse
const s = "Hello Mocha World";
let reversed = "";
for (let k = 0; k < 10000; k++) {
    reversed = s.split("").reverse().join("");
}
console.log(reversed);

// Benchmark 4: Split
const csv = "one,two,three,four,five";
let count = 0;
for (let l = 0; l < 10000; l++) {
    const parts = csv.split(",");
    count += parts.length;
}
console.log(count);
