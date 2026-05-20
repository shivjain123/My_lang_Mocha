function main(didLoad){
    """var words: str[] = ["bat", "mat", "cat", "rat"];
    var firstChars: str[] = [word.charAt(0) for each word in words];
    print(firstChars[0]);"""

    var xs: int[] = [1, 2, 3];
var ys: int[] = [4, 5, 6];
var pairs: int[][] = [[x+y for each x in xs] for each y in ys];
print(pairs[0][0], newLine=true);  // 5 (1+4)
print(pairs[1][0], newLine=true);  // 6 (1+5)
};