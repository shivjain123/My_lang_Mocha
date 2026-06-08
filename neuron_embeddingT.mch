from "mocha-neuron" import *;

function main(didLoad) -> null {
    rand_seed(42);

    // Embedding: vocab=10, d_model=4
    var emb: Embedding = Embedding(10, 4);

    // PositionalEncoding: max_len=8, d_model=4
    var pe: PositionalEncoding = PositionalEncoding(8, 4);

    // token IDs
    var ids: int[] = [2, 5, 7];

    // forward through embedding
    var embedded: Tensor = emb.forward(ids);
    print("Embedded [3 x 4]:", newLine=true);
    embedded.show();

    // add positional encoding
    var encoded: Tensor = pe.encode(embedded);
    print("After positional encoding [3 x 4]:", newLine=true);
    encoded.show();

    embedded.dispose();
    encoded.dispose();
    emb.dispose();
    pe.dispose();
};