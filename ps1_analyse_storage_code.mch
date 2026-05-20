from "mocha-stats" import *;
from "mocha-string" import *;

function analyze_storage(file: str) -> null {
    var data: str[] = file.split("\\n");
    var sizes: float[] = [];
    
    for each line in data {
        var parts: str[] = line.split(",");
        // Parse CSV, extract sizes, compute stats
        var size: float = float(parts[1].rip());
        sizes.push(size);
    };
    
    print("Total files: ", sizes.length, newLine=true);
    print("Total size: ", sum(sizes), " MB", newLine=true);
    print("Average size: ", sizes.mean(), " MB", newLine=true);
};