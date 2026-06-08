"""from "mocha-string" import *;

function main(didLoad) -> null {
    var words: str[] = [];
    words.push("hello");
    words.push("world");
    words.push("mocha");

    var i: int = 0;
    while (i < words.length) {
        print(words[i], "\n");
        i = i + 1;
    };
};"""

class TestArr {
    var nums: int[];
    
    function constructor() -> null {
        this.nums = [];
        this.nums.push(10);
        this.nums.push(20);
        this.nums.push(30);
    };
    
    function get(i: int) -> int {
        return this.nums[i];
    };
};

function main(didLoad) -> null {
    var t: TestArr = TestArr();
    print(t.get(0), "\n");
    print(t.get(1), "\n");
    print(t.get(2), "\n");
};