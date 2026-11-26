from "mocha-ds" import *;

function main(didLoad) -> null {
    var t: RBTree = RBTree();
    t.insert(ds_int(5));
    t.insert(ds_int(3));
    t.insert(ds_int(8));
    t.insert(ds_int(3));
    t.insert(ds_int(5));
    print("size after duplicates ", t.size, newLine=true);
    t.inorder();
    t.remove(ds_int(3));
    print("size after remove ", t.size, newLine=true);
    print("contains 3 ", ds_to_str(ds_bool(t.contains(ds_int(3)))), newLine=true);
    print("min ", ds_to_str(t.min()), newLine=true);
    t.remove(ds_int(5));
    t.remove(ds_int(8));
    print("empty ", ds_to_str(ds_bool(t.is_empty())), newLine=true);
};