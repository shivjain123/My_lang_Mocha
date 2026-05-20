from "mocha-math" import *;

function shivGaps(n: int) -> int[] {
    var gaps: int[] = alloc int[13];
    gaps[0] = 1; gaps[1] = 4; gaps[2] = 13;
    gaps[3] = 35; gaps[4] = 89; gaps[5] = 226;
    gaps[6] = 577; gaps[7] = 1625; gaps[8] = 5937;
    gaps[9] = 23642; gaps[10] = 94557; gaps[11] = 378231;
    gaps[12] = 1512926;
    return gaps;
};

function shellSort(arr: int[], gaps: int[]) -> null {
    var n: int = arr.length;
    
    for (var i: int = gaps.length - 1; i >= 0; i--){
        var gap: int = gaps[i];
        
        for (var j: int = gap; j < n; j++) {
            var temp: int = arr[j];
            var k: int = j - gap;
            
            while (k >= 0 && arr[k] > temp) {
                arr[k + gap] = arr[k];
                k = k - gap;
            };
            
            arr[k + gap] = temp;
        };
    };
};

function shell(didLoad){
    var data: int[] = [64, 25, 12, 22, 11, 35, 90, 18, 42, 7];
    print("Before: ");
    for each x in data { print(x, " "); };
    print(newLine=true);
    
    var gaps: int[] = shivGaps(100);
    shellSort(data, gaps);
    
    print("After:  ");
    for each d in data { print(d, " "); };
    print(newLine=true);
};