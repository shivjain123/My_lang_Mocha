// mocha-lib-deps: mocha-string
// ============================================================
// codegen_utils.mch — CodeGen state and utilities
// ============================================================

from "./typechecker.mch" import *;

// ============================================================
// CodeGen state
// ============================================================

//Helper
function splitComma(s: str) -> str[] {
    var result: str[] = [];
    var current: str = "";
    var i: int = 0;
    while (i < s.length) {
        var ch: str = s.charAt(i);
        if (ch == ",") {
            if (current.length > 0) {
                result.push(current);
                current = "";
            };
        } else {
            current = current + ch;
        };
        i = i + 1;
    };
    if (current.length > 0) {
        result.push(current);
    };
    return result;
};

class CodeGen {
    var output:               str[];
    var temp_count:           int;
    var str_count:            int;
    var string_const_keys:    str[];
    var string_const_ids:     int[];
    var local_ptrs:           HashTable;
    var local_types:          HashTable;
    var local_mocha_types:    HashTable;
    var global_ptrs:          HashTable;
    var global_mocha_types:   HashTable;
    var current_return_type:  str;
    var in_function:          bool;
    var current_class:        str;
    var class_fields:         HashTable;
    var class_mocha_fields:   HashTable;
    var class_parents:        HashTable;
    var method_return_types:  HashTable;
    var lib_functions:        HashTable;
    var ext_native_names:     HashTable;
    var extra_declares:       str[];
    var type_declarations:    str[];
    var entry_allocas:        str[];
    var lib_init_calls:       str[];
    var classes_with_ctors:   str[];
    var class_node_list:      ASTNode[];
    var class_node_index:     HashTable;
    var local_name_counts:    HashTable;
    var tag_types:            str[];
    var expected_assign_type: str;
    var break_label:    str;
    var continue_label: str;
    var is_lib:         bool;

    function constructor() -> null {
        this.output               = [];
        this.temp_count           = 0;
        this.str_count            = 0;
        this.string_const_keys    = [];
        this.string_const_ids     = [];
        this.local_ptrs           = HashTable();
        this.local_types          = HashTable();
        this.local_mocha_types    = HashTable();
        this.global_ptrs          = HashTable();
        this.global_mocha_types   = HashTable();
        this.current_return_type  = "void";
        this.in_function          = false;
        this.current_class        = "";
        this.class_fields         = HashTable();
        this.class_mocha_fields   = HashTable();
        this.class_parents        = HashTable();
        this.method_return_types  = HashTable();
        this.lib_functions        = HashTable();
        this.ext_native_names     = HashTable();
        this.extra_declares       = [];
        this.type_declarations    = [];
        this.entry_allocas        = [];
        this.lib_init_calls       = [];
        this.classes_with_ctors   = [];
        this.class_node_list      = [];
        this.class_node_index     = HashTable();
        this.local_name_counts    = HashTable();
        this.tag_types            = [];
        this.expected_assign_type = "";
        this.break_label          = "";
        this.continue_label          = "";
        this.is_lib         = false;

        // Built-in class fields — encoded as "name|llvm_type" comma-joined
        this.class_fields.put("StringBuilder", "data|i8*,length|i32,capacity|i32");
        this.class_fields.put("Complex",       "real|double,imag|double");
        this.class_fields.put("File",          "handle|i8*,path|i8*,mode|i8*,is_open|i8");
        this.class_fields.put("HashTable",     "entries|i8*,capacity|i32,count|i32,used|i32");

        this.class_mocha_fields.put("StringBuilder", "data|str,length|int,capacity|int");
        this.class_mocha_fields.put("Complex",       "real|float,imag|float");
        this.class_mocha_fields.put("File",          "handle|str,path|str,mode|str,is_open|bool");
        this.class_mocha_fields.put("HashTable",     "entries|str,capacity|int,count|int,used|int");

        // Built-in method return types
        this.method_return_types.put("StringBuilder_toString", "i8*");
        this.method_return_types.put("StringBuilder_reverse",  "i8*");
        this.method_return_types.put("StringBuilder_clear",    "void");
        this.method_return_types.put("StringBuilder_append",   "void");
        this.method_return_types.put("StringBuilder_length",   "i32");
        this.method_return_types.put("Complex_toString",       "i8*");
        this.method_return_types.put("Complex_abs",            "double");
        this.method_return_types.put("Complex_add",            "%struct.MochaComplex*");
        this.method_return_types.put("Complex_sub",            "%struct.MochaComplex*");
        this.method_return_types.put("Complex_mul",            "%struct.MochaComplex*");
        this.method_return_types.put("Complex_div",            "%struct.MochaComplex*");
        this.method_return_types.put("Complex_conjugate",      "%struct.MochaComplex*");
        this.method_return_types.put("File_read",              "i8*");
        this.method_return_types.put("File_readLine",          "i8*");
        this.method_return_types.put("File_write",             "void");
        this.method_return_types.put("File_close",             "void");
        this.method_return_types.put("HashTable_put",          "void");
        this.method_return_types.put("HashTable_get",          "i8*");
        this.method_return_types.put("HashTable_has",          "i8");
        this.method_return_types.put("HashTable_remove",       "void");
        this.method_return_types.put("HashTable_size",         "i32");
        this.method_return_types.put("HashTable_clear",        "void");
        this.method_return_types.put("HashTable_keys",         "%MochaArray*");
        this.method_return_types.put("HashTable_values",       "%MochaArray*");
        this.method_return_types.put("HashTable_free",         "void");
        this.method_return_types.put("mocha_error",  "void");
        this.method_return_types.put("puts",         "i32");
        this.method_return_types.put("exit_program", "void");
    };

    // --------------------------------------------------------
    // Core utilities
    // --------------------------------------------------------

    function emit(line: str) -> null {
        this.output.push(line);
    };

    function freshTemp() -> str {
        var name: str = "%t" + str(this.temp_count);
        this.temp_count = this.temp_count + 1;
        return name;
    };

    function freshLabel(prefix: str) -> str {
        var name: str = prefix + "_" + str(this.temp_count);
        this.temp_count = this.temp_count + 1;
        return name;
    };

    function freshStrConst() -> int {
        var id: int = this.str_count;
        this.str_count = this.str_count + 1;
        return id;
    };

    // --------------------------------------------------------
    // String constant pool
    // --------------------------------------------------------

    function internString(s: str) -> int {
        var i: int = 0;
        while (i < this.string_const_keys.length) {
            if (this.string_const_keys[i] == s) {
                return this.string_const_ids[i];
            };
            i = i + 1;
        };
        var id: int = this.freshStrConst();
        this.string_const_keys.push(s);
        this.string_const_ids.push(id);
        return id;
    };

    // --------------------------------------------------------
    // Type conversion
    // --------------------------------------------------------

    function toLLVMType(mocha_type: str) -> str {
        if (mocha_type.length >= 1) {
            if (mocha_type.charAt(0) == "(") { return "%MochaTuple*"; };
        };
        if (mocha_type.length >= 4) {
            if (mocha_type.substring(0, 3) == "set") { return "%MochaSet*"; };
        };
        if (mocha_type.contains("[][]")) { return "%MochaArray2D*"; };
        if (mocha_type.contains("["))    { return "%MochaArray*"; };
        if (mocha_type == "dict")        { return "%MochaDict*"; };
        if (mocha_type == "lambda")      { return "i8*"; };
        if (mocha_type == "int")         { return "i32"; };
        if (mocha_type == "vast")        { return "i64"; };
        if (mocha_type == "float")       { return "double"; };
        if (mocha_type == "bool")        { return "i8"; };
        if (mocha_type == "str")         { return "i8*"; };
        if (mocha_type == "null")        { return "void"; };
        if (mocha_type == "Result")      { return "i32"; };
        if (mocha_type == "StringBuilder") { return "%struct.MochaStringBuilder*"; };
        if (mocha_type == "Complex")     { return "%struct.MochaComplex*"; };
        if (mocha_type == "File")        { return "%struct.MochaFile*"; };
        if (mocha_type == "HashTable")   { return "%struct.MochaHashTable*"; };
        if (mocha_type == "unknown")     { return "i32"; };
        // tag type check
        var ti: int = 0;
        while (ti < this.tag_types.length) {
            if (this.tag_types[ti] == mocha_type) { return "i32"; };
            ti = ti + 1;
        };
        // user class
        return "%struct." + mocha_type + "*";
    };

    function toLLVMParamType(mocha_type: str) -> str {
        if (mocha_type == "null") { return "i8*"; };
        return this.toLLVMType(mocha_type);
    };

    function isFloatType(llvm_type: str) -> bool {
        return llvm_type == "double";
    };

    function isIntType(llvm_type: str) -> bool {
        return llvm_type == "i32" || llvm_type == "i64" || llvm_type == "i8";
    };

    // --------------------------------------------------------
    // Name mangling
    // --------------------------------------------------------

    function mangleName(name: str) -> str {
        if (name == "abs"    || name == "pow"    || name == "sqrt" ||
            name == "sin"    || name == "cos"    || name == "tan"  ||
            name == "log"    || name == "exp"    || name == "ceil" ||
            name == "floor"  || name == "round"  || name == "rand" ||
            name == "exit"   || name == "printf" || name == "puts") {
            return "mocha_user_" + name;
        };
        return name;
    };

    // --------------------------------------------------------
    // Local variable helpers
    // --------------------------------------------------------

    function uniquePtrName(name: str) -> str {
        if (this.local_name_counts.has(name)) {
            var count: int = this.local_name_counts.get(name).toInt();
            count = count + 1;
            this.local_name_counts.put(name, str(count));
            return name + "." + str(count);
        };
        this.local_name_counts.put(name, "0");
        return name;
    };

    function declareLocal(name: str, ptr: str, llvm_type: str, mocha_type: str) -> null {
        this.local_ptrs.put(name, ptr);
        this.local_types.put(name, llvm_type);
        this.local_mocha_types.put(name, mocha_type);
    };

    function hasLocal(name: str) -> bool {
        return this.local_ptrs.has(name);
    };

    function getLocalPtr(name: str) -> str {
        return this.local_ptrs.get(name);
    };

    function getLocalType(name: str) -> str {
        return this.local_types.get(name);
    };

    function getLocalMochaType(name: str) -> str {
        return this.local_mocha_types.get(name);
    };

    function clearLocals() -> null {
        this.local_ptrs           = HashTable();
        this.local_types          = HashTable();
        this.local_mocha_types    = HashTable();
        this.local_name_counts    = HashTable();
        this.entry_allocas        = [];
    };

    // --------------------------------------------------------
    // Class field helpers
    // encode: "f1|llvm1,f2|llvm2,..."
    // --------------------------------------------------------

    function getFieldIndex(class_name: str, field_name: str) -> int {
        if (this.class_fields.has(class_name) == false) { return -1; };
        var encoded: str = this.class_fields.get(class_name);
        var fields: str[] = splitComma(encoded);
        var i: int = 0;
        while (i < fields.length) {
            var pair: str = fields[i];
            var fname: str = this.fieldName(pair);
            if (fname == field_name) { return i; };
            i = i + 1;
        };
        return -1;
    };

    function getFieldLLVMType(class_name: str, field_name: str) -> str {
        if (this.class_fields.has(class_name) == false) { return "i8*"; };
        var encoded: str = this.class_fields.get(class_name);
        var fields: str[] = splitComma(encoded);
        var i: int = 0;
        while (i < fields.length) {
            var pair: str = fields[i];
            if (this.fieldName(pair) == field_name) {
                return this.fieldType(pair);
            };
            i = i + 1;
        };
        return "i8*";
    };

    function getFieldMochaType(class_name: str, field_name: str) -> str {
        if (this.class_mocha_fields.has(class_name) == false) { return "unknown"; };
        var encoded: str = this.class_mocha_fields.get(class_name);
        var fields: str[] = splitComma(encoded);
        var i: int = 0;
        while (i < fields.length) {
            var pair: str = fields[i];
            if (this.fieldName(pair) == field_name) {
                return this.fieldType(pair);
            };
            i = i + 1;
        };
        return "unknown";
    };

    // "name|type" -> "name"
    function fieldName(pair: str) -> str {
        var i: int = 0;
        while (i < pair.length) {
            if (pair.charAt(i) == "|") {
                return pair.substring(0, i - 1);
            };
            i = i + 1;
        };
        return pair;
    };

    // "name|type" -> "type"
    function fieldType(pair: str) -> str {
        var i: int = 0;
        while (i < pair.length) {
            if (pair.charAt(i) == "|") {
                if (i + 1 <= pair.length - 1) {
                    return pair.substring(i + 1, pair.length - 1);
                };
                return "";
            };
            i = i + 1;
        };
        return "";
    };

    function registerClassFields(class_name: str, body: ASTNode[]) -> null {
        var llvm_encoded:  str = "";
        var mocha_encoded: str = "";
        var i: int = 0;
        while (i < body.length) {
            var member: ASTNode = body[i];
            if (member.kind == "FieldDecl") {
                var llvm_t:  str = this.toLLVMType(member.type_str);
                var mocha_t: str = member.type_str;
                if (llvm_encoded != "") {
                    llvm_encoded  = llvm_encoded  + ",";
                    mocha_encoded = mocha_encoded + ",";
                };
                llvm_encoded  = llvm_encoded  + member.value + "|" + llvm_t;
                mocha_encoded = mocha_encoded + member.value + "|" + mocha_t;
            };
            i = i + 1;
        };
        this.class_fields.put(class_name, llvm_encoded);
        this.class_mocha_fields.put(class_name, mocha_encoded);
    };

    // --------------------------------------------------------
    // Preamble emission
    // --------------------------------------------------------

    function emitPreamble() -> null {
        this.emit("; Mocha Compiler — Self-Hosted Codegen");
        this.emit("target triple = \"x86_64-pc-windows-msvc\"");
        this.emit("");

        // Type declarations
        this.emit("%MochaArray   = type { i8*, i32, i32, i32, i32 }");
        this.emit("%MochaArray2D = type { %MochaArray**, i32, i32, i32, i32, i32 }");
        this.emit("%MochaTuple   = type { i8*, i32 }");
        this.emit("%MochaDict    = type { i8*, i32, i32 }");
        this.emit("%MochaSet     = type { i8*, i32, i32, i32 }");
        this.emit("");

        // GC
        this.emit("declare void @mocha_gc_init()");
        this.emit("declare void @mocha_gc_collect()");
        this.emit("declare void @mocha_gc_shutdown()");
        this.emit("");

        // Strings
        this.emit("declare i8* @mocha_str_literal(i8*)");
        this.emit("declare i8* @mocha_str_concat(i8*, i8*)");
        this.emit("declare i8* @mocha_int_to_str(i32)");
        this.emit("declare i8* @mocha_float_to_str(double)");
        this.emit("declare i8* @mocha_vast_to_str(i64)");
        this.emit("declare i32 @mocha_str_eq(i8*, i8*)");
        this.emit("declare i32 @mocha_str_length(i8*)");
        this.emit("declare i8* @mocha_str_charat(i8*, i32)");
        this.emit("declare i32 @mocha_str_to_int(i8*)");
        this.emit("declare double @mocha_str_to_float(i8*)");
        this.emit("declare i64 @mocha_str_to_vast(i8*)");
        this.emit("");

        // Print
        this.emit("declare void @mocha_print_str(i8*, i8)");
        this.emit("declare void @mocha_print_int(i32, i8)");
        this.emit("declare void @mocha_print_float(double, i8)");
        this.emit("declare void @mocha_print_bool(i8, i8)");
        this.emit("declare void @mocha_print_vast(i64, i8)");
        this.emit("declare void @mocha_print_stderr(i8*)");
        this.emit("");

        // Float ops
        this.emit("declare double @mocha_float_add(double, double)");
        this.emit("declare double @mocha_float_sub(double, double)");
        this.emit("declare double @mocha_float_mul(double, double)");
        this.emit("declare double @mocha_float_div(double, double)");
        this.emit("declare double @mocha_float_mod(double, double)");
        this.emit("");

        // C stdlib
        this.emit("declare i8* @malloc(i64)");
        this.emit("declare i32 @atoi(i8*)");
        this.emit("declare double @atof(i8*)");
        this.emit("declare i32 @strcmp(i8*, i8*)");
        this.emit("declare void @mocha_exit(i32)");
        this.emit("declare void @llvm.memset.p0i8.i64(i8*, i8, i64, i1)");
        this.emit("declare i32 @puts(i8*)");
        this.emit("");

        // Arrays
        this.emit("declare %MochaArray* @mocha_array_new(i32, i32, i32)");
        this.emit("declare %MochaArray* @mocha_array_alloc_filled(i32, i32)");
        this.emit("declare void @mocha_array_set(%MochaArray*, i32, i8*)");
        this.emit("declare void @mocha_array_get(%MochaArray*, i32, i8*)");
        this.emit("declare void @mocha_array_push(%MochaArray*, i8*)");
        this.emit("declare void @mocha_array_pop(%MochaArray*, i8*, i8*)");
        this.emit("declare void @mocha_array_init_set(%MochaArray*, i32, i8*)");
        this.emit("declare i32  @mocha_array_length(%MochaArray*)");
        this.emit("declare %MochaArray* @mocha_array_copy(%MochaArray*)");
        this.emit("");

        // HashTable
        this.emit("declare %struct.MochaHashTable* @mocha_ht_new()");
        this.emit("declare void @mocha_ht_put(%struct.MochaHashTable*, i8*, i8*)");
        this.emit("declare i8*  @mocha_ht_get(%struct.MochaHashTable*, i8*)");
        this.emit("declare i8   @mocha_ht_has(%struct.MochaHashTable*, i8*)");
        this.emit("declare void @mocha_ht_remove(%struct.MochaHashTable*, i8*)");
        this.emit("declare i32  @mocha_ht_size(%struct.MochaHashTable*)");
        this.emit("declare void @mocha_ht_clear(%struct.MochaHashTable*)");
        this.emit("declare %MochaArray* @mocha_ht_keys(%struct.MochaHashTable*)");
        this.emit("declare %MochaArray* @mocha_ht_values(%struct.MochaHashTable*)");
        this.emit("declare void @mocha_ht_free(%struct.MochaHashTable*)");
        this.emit("");

        // tell / file / exists
        this.emit("declare i8* @mocha_tell(i8*)");
        this.emit("declare %struct.MochaFile* @mocha_file_open(i8*, i8*)");
        this.emit("declare i8*  @mocha_file_read(%struct.MochaFile*)");
        this.emit("declare i8*  @mocha_file_readline(%struct.MochaFile*)");
        this.emit("declare void @mocha_file_write(%struct.MochaFile*, i8*)");
        this.emit("declare void @mocha_file_close(%struct.MochaFile*)");
        this.emit("declare i8   @mocha_file_exists(i8*)");
        this.emit("");

        // StringBuilder
        this.emit("declare %struct.MochaStringBuilder* @mocha_sb_new()");
        this.emit("declare void @mocha_sb_append(%struct.MochaStringBuilder*, i8*)");
        this.emit("declare i8*  @mocha_sb_tostring(%struct.MochaStringBuilder*)");
        this.emit("declare void @mocha_sb_clear(%struct.MochaStringBuilder*)");
        this.emit("declare i32  @mocha_sb_length(%struct.MochaStringBuilder*)");
        this.emit("declare void @mocha_sb_free(%struct.MochaStringBuilder*)");
        this.emit("");

        // Complex
        this.emit("declare %struct.MochaComplex* @mocha_complex_new(double, double)");
        this.emit("declare %struct.MochaComplex* @mocha_complex_add(%struct.MochaComplex*, %struct.MochaComplex*)");
        this.emit("declare %struct.MochaComplex* @mocha_complex_sub(%struct.MochaComplex*, %struct.MochaComplex*)");
        this.emit("declare %struct.MochaComplex* @mocha_complex_mul(%struct.MochaComplex*, %struct.MochaComplex*)");
        this.emit("declare %struct.MochaComplex* @mocha_complex_div(%struct.MochaComplex*, %struct.MochaComplex*)");
        this.emit("declare double @mocha_complex_abs(%struct.MochaComplex*)");
        this.emit("declare i8*   @mocha_complex_tostring(%struct.MochaComplex*)");
        this.emit("declare %struct.MochaComplex* @mocha_complex_conjugate(%struct.MochaComplex*)");
        this.emit("");
    };

    // --------------------------------------------------------
    // Output finalizer
    // --------------------------------------------------------

    function getOutput() -> str {
        var result: str = "";
        var i: int = 0;
        while (i < this.output.length) {
            result = result + this.output[i] + "\n";
            i = i + 1;
        };
        return result;
    };

    function writeOutput(filename: str) -> null {
        var f: File = open(filename, "write");
        var i: int = 0;
        while (i < this.output.length) {
            f.write(this.output[i] + "\n");
            i = i + 1;
        };
        f.close();
    };
};