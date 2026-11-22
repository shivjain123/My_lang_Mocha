from "mocha-processing" import *;

function main(didLoad) -> null {
    // int helpers
    var nums: int[] = [1, 2, 3, 4, 5, 6, 7, 8];
    var evens: int[] = filter(nums, lambda (x: int) -> bool: x % 2 == 0);
    print(evens.length, newLine=true);
    print(evens[0], newLine=true);
    print(evens[3], newLine=true);

    var squares: int[] = map(nums, lambda (x: int) -> int: x * x);
    print(squares[0], newLine=true);
    print(squares[7], newLine=true);

    print(reduce(nums, lambda (a: int, b: int) -> int: a + b, 0), newLine=true);
    print(reduce(nums, lambda (a: int, b: int) -> int: a * b, 1), newLine=true);

    // float helpers
    var fl: float[] = [0.5, 1.5, 2.5, 3.5];
    var big: float[] = filterFloat(fl, lambda (x: float) -> bool: x > 2.0);
    print(big.length, newLine=true);
    print(big[0], newLine=true);

    var doubled: float[] = mapFloat(fl, lambda (x: float) -> float: x * 2.0);
    print(doubled[1], newLine=true);
    print(doubled[3], newLine=true);

    print(reduceFloat(fl, lambda (a: float, b: float) -> float: a + b, 0.0), newLine=true);

    // str helpers
    var words: str[] = ["ant", "bee", "cattle", "dog", "eagle"];
    var longw: str[] = filterStr(words, lambda (x: str) -> bool: x.length > 3);
    print(longw.length, newLine=true);
    print(longw[0], newLine=true);

    var shout: str[] = mapStr(words, lambda (x: str) -> str: x + "!");
    print(shout[0], newLine=true);

    print(reduceStr(words, lambda (a: str, b: str) -> str: a + "-" + b, ""), newLine=true);
};