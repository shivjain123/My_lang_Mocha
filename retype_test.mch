function main(didLoad) -> null {
    var s: set<int> = <1, 2, 3>;
    
    // test 1: retype without clean — should warn about non-empty
    s.retype(float);
    
    // test 2: retype with clean first — should only warn about data loss
    var s2: set<int> = <10, 20, 30>;
    s2.clean();
    s2.retype(str);
    
    // test 3: retype to same type — should still warn
    var s3: set<float> = <1.1, 2.2>;
    s3.clean();
    s3.retype(float);
    
    print("done", newLine=true);
};