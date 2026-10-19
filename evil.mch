class EvilNumberChecker {
    shared function getInput() -> int {
        return tell("Please enter the number: ").toInt();
    };

    shared function isEvil(number: int) -> bool {
        var count: int = 0;
        var n: int = number;
        while (n > 0) {
            count = count + (n & 1);
            n = n >> 1;
        };
        return (count % 2 == 0);
    };
};

function main(didLoad) {
    var number: int = EvilNumberChecker.getInput();
    if (EvilNumberChecker.isEvil(number)) {
        print("EVIL.", newLine=true);
    } else {
        print("NOT Evil.", newLine=true);
    };
};