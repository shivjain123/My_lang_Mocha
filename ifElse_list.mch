function test(didLoad){
    var nums: int[] = [1, 2, 3, 4, 5];
var labels: str[] = ["even" if x%2==0 else "odd" for each x in nums];
print(labels[0], newLine=true);  // odd  (1)
print(labels[1], newLine=true);  // even (2)
print(labels[2], newLine=true);  // odd  (3)
};