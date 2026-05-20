function main(didLoad) -> null {
    var nums: int[] = [3, 1, 4, 1, 5, 9, 2, 6];
    print(nums.min(), newLine=true);  // 1
    print(nums.max(), newLine=true);  // 9
    
    var prices: float[] = [1.5, 3.2, 0.8, 2.1];
    print(prices.min(), newLine=true);  // 0.8
    print(prices.max(), newLine=true);  // 3.2
    
    var words: str[] = ["banana", "apple", "cherry"];
    print(words.min(), newLine=true);  // apple
    print(words.max(), newLine=true);  // cherry
};