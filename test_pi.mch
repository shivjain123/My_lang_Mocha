from "mocha-stats" import *;

function main(didLoad) -> null {
    var a: float[] = [1.0, 2.0, 3.0, 4.0];
    var b: float[] = [2.5, 0.5, 3.0, 7.0];

    print(euclidean(a, b), newLine=true);
    print(manhattan(a, b), newLine=true);
    print(chebyshev(a, b), newLine=true);
    print(minkowski(a, b, 3.0), newLine=true);
    print(minkowski(a, b, 1.5), newLine=true);
    print(cosine(a, b), newLine=true);

    // parallel vectors: cosine similarity must be 1
    var c: float[] = [1.0, 0.0, 2.0];
    var d: float[] = [2.0, 0.0, 4.0];
    print(cosine(c, d), newLine=true);

    // haversine: London-Paris, Sydney-New York, and a very short hop
    print(haversine(51.5074, -0.1278, 48.8566, 2.3522), newLine=true);
    print(haversine(-33.8688, 151.2093, 40.7128, -74.0060), newLine=true);
    print(haversine(12.9716, 77.5946, 12.9816, 77.6046), newLine=true);

    // hamming
    print(hamming("karolin", "kathrin"), newLine=true);
};