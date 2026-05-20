#include <iostream>
#include <string>
#include <vector>
#include <algorithm>
#include <sstream>

int main() {
    // Benchmark 1: String concatenation loop
    std::string result = "";
    result.reserve(10000);  // pre-allocate for fairness
    for (int i = 0; i < 10000; i++) {
        result += "a";
    }
    std::cout << result.length() << std::endl;

    // Benchmark 2: String contains (find)
    std::string haystack = "the quick brown fox jumps over the lazy dog";
    int found = 0;
    for (int j = 0; j < 10000; j++) {
        if (haystack.find("fox") != std::string::npos) {
            found++;
        }
    }
    std::cout << found << std::endl;

    // Benchmark 3: String reverse
    std::string s = "Hello Mocha World";
    std::string reversed = "";
    for (int k = 0; k < 10000; k++) {
        reversed = s;
        std::reverse(reversed.begin(), reversed.end());
    }
    std::cout << reversed << std::endl;

    // Benchmark 4: Split (manual — no built-in split in C++)
    std::string csv = "one,two,three,four,five";
    int count = 0;
    for (int l = 0; l < 10000; l++) {
        std::stringstream ss(csv);
        std::string token;
        int parts = 0;
        while (std::getline(ss, token, ',')) {
            parts++;
        }
        count += parts;
    }
    std::cout << count << std::endl;

    return 0;
}
