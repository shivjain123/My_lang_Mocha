# String benchmark - Python

# Benchmark 1: String concatenation loop
result = ""
for i in range(10000):
    result += "a"
print(len(result))

# Benchmark 2: String contains
haystack = "the quick brown fox jumps over the lazy dog"
found = 0
for j in range(10000):
    if "fox" in haystack:
        found += 1
print(found)

# Benchmark 3: String reverse
s = "Hello Mocha World"
for k in range(10000):
    r = s[::-1]
print(s[::-1])

# Benchmark 4: Split
csv = "one,two,three,four,five"
count = 0
for l in range(10000):
    parts = csv.split(",")
    count += len(parts)
print(count)
