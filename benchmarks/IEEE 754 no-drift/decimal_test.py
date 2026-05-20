total = 0.0
for i in range(10000000):  # 10 million
    total += 0.1

print(f"Result: {total}")
print(f"Expected: {10000000 * 0.1}")
print(f"Error: {abs(total - 1000000.0)}")