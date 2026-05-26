"""function test(didLoad) -> null {
    var arr: int[] = [1, 2, 3];
    print(arr[10], newLine=true);
};"""

function inner() -> null {
    var arr: int[] = [1, 2, 3];
    print(arr[10], newLine=true);
};
function outer(didLoad) -> null { //null can be skipped but int/str/etc. can't be. didLoad marks main function.
    inner();
};