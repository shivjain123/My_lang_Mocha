function main(didLoad){
    var xs: int[] = [1, 2, 3];
    var ys: int[] = [4, 5, 6];
    var pairs: int[][] = [[x+y for each x in xs] for each y in ys];
    print(pairs[0][0], newLine=true);  // 5 (1+4)
    print(pairs[1][0], newLine=true);  // 6 (1+5)
};