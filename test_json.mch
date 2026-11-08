function main(didLoad){
    var d: dict = {"name": "Sh\"iv\n", "pi": 3.0, "xs": [1,2,3], "names": ["a","b"], "in": {"ok": true, "big": [5000000000, 1]}};
    var text: str = d.jsonify();
    var back: dict = text.dictify();
    print(text, newLine=true);
    print(back.jsonify(), newLine=true);
};