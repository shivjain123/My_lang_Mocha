from "./symtable.mch" import *;

function puts(s: str) -> int native puts;

function testSymTable(didLoad) -> null {
    // Create a symbol info
    var info: SymbolInfo = SymbolInfo();
    info.type        = "int";
    info.is_const    = false;
    info.is_function = false;
    info.is_class    = false;
    info.visibility  = "public";

    // Create symbol table and declare
    var st: SymbolTable = SymbolTable();
    st.declare("x", info);

    // Lookup
    var found: SymbolInfo = st.lookup("x");
    if (found != null) {
        puts(found.type);        // int
        puts(found.visibility);  // public
    };

    // Scope push/pop
    st.push_scope();
    var info2: SymbolInfo = SymbolInfo();
    info2.type = "float";
    st.declare("y", info2);

    var found2: SymbolInfo = st.lookup("y");
    if (found2 != null) {
        puts(found2.type);  // float
    };

    // x still visible from outer scope
    var found3: SymbolInfo = st.lookup("x");
    if (found3 != null) {
        puts(found3.type);  // int
    };

    st.pop_scope();

    // y gone after pop
    var gone: SymbolInfo = st.lookup("y");
    if (gone == null) {
        puts("y gone after pop: true");  // true
    };
};