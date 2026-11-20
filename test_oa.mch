// mocha-native: d_triple.o

function d_triple(x: int) -> int native d_triple;

function main(didLoad) -> null {
    print(d_triple(11), newLine=true);
};