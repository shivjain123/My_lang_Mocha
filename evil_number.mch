class EvilNumberChecker {
    shared function getInput() -> int {
        return tell("Please enter the number: ").toInt();
    };

    shared function convertToBinary(number: int) -> str {
        if (number == 0) { return ""; };
        var remainder: int = number % 2;
        return convertToBinary(number / 2) + str(remainder);
    };

    shared function isEvil(binString: str) -> bool {
        var countOfOnes: int = 0;
        for (var i: int = 0; i < binString.length; i++) {
            if (binString.charAt(i) == "1") { countOfOnes++; };
        };
        return (countOfOnes % 2 == 0);
    };
};

function main(didLoad) {
    var number: int = EvilNumberChecker.getInput();
    var binary: str = EvilNumberChecker.convertToBinary(number);
    if (EvilNumberChecker.isEvil(binary)) {
        print("EVIL.", newLine=true);
    } else {
        print("NOT Evil.", newLine=true);
    };
};