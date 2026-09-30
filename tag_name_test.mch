tag DSKind { INT, FLOAT, STR, BOOL };

function main(didLoad) -> null {
    var a: DSKind = DSKind.INT;
    var b: DSKind = DSKind.STR;
    var msg: str = "cannot compare " + a.name() + " with " + b.name() + ".";
    print(msg, newLine=true);
};