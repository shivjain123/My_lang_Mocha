from "mocha-string" import *;

function main(didLoad) -> null {
    var w: File = open("csv_test.csv", "write");
    w.write("name,note,score\n");
    w.write("\"Smith, John\",plain,42\n");
    w.write("a,\"she said \"\"hi\"\"\",7\n");
    w.write("b,\"line1\nline2\",9\n");
    w.write("\n");
    w.write("c,last,1\n");
    w.close();

    var r: File = open("csv_test.csv", "read");
    var n: int = 0;
    while (!r.eof()) {
        var rec: str[] = r.readCsvRecord();
        print("record ", n, " has ", rec.length, " fields:", newLine=true);
        var k: int = 0;
        while (k < rec.length) {
            print("  [" + rec[k] + "]", newLine=true);
            k = k + 1;
        };
        n = n + 1;
    };
    r.close();
};