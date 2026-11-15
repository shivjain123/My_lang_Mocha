from "mocha-stats" import *;
from "mocha-string" import *;

function analyze_storage(didLoad, file: str) -> null {
    var data: str[] = file.split("\\n");
    var sizes: float[] = [];
    
    for each line in data {
        var parts: str[] = line.split(",");
        // Parse CSV, extract sizes, compute stats
        var size: float = parts[1].rip().toFloat();
        sizes.push(size);
    };

    var total_size: float = 0;

    for each size in sizes {
        total_size += size;
    };
    
    print("Total files: ", sizes.length, newLine=true);
    print("Total size: ", total_size, " MB", newLine=true);
    print("Average size: ", sizes.mean(), " MB", newLine=true);
};