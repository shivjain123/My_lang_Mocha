// mocha-lib-deps: mocha-string
// ============================================================
// codegen_decl.mch — Function, class, extend, tag declarations
// ============================================================

extend CodeGen {

    // --------------------------------------------------------
    // Helper: check if last emitted line is a terminator
    // --------------------------------------------------------

    function lastIsTerminator() -> bool {
        if (this.output.length == 0) { return false; };
        var last: str = this.output[this.output.length - 1];
        if (last.contains("ret "))       { return true; };
        if (last.contains("br "))        { return true; };
        if (last.contains("unreachable")) { return true; };
        return false;
    };

    function emitBlank() -> null {
        this.emit("");
    };

    // --------------------------------------------------------
    // Two-pass function emission helper
    // saves/restores output buffer so allocas go first
    // --------------------------------------------------------

    function beginFunctionBody() -> str[] {
        var saved: str[] = this.output;
        this.output      = [];
        this.entry_allocas = [];
        return saved;
    };

    function endFunctionBody(saved: str[], ret_llvm: str, func_name: str, param_str: str) -> null {
        // Add terminator if needed
        if (this.lastIsTerminator() == false) {
            if (ret_llvm == "void") {
                this.emit("  ret void");
            } else if (ret_llvm == "double") {
                this.emit("  ret double 0.0");
            } else if (ret_llvm.charAt(ret_llvm.length - 1) == "*") {
                this.emit("  ret " + ret_llvm + " null");
            } else {
                this.emit("  ret " + ret_llvm + " 0");
            };
        };

        var body_lines: str[] = this.output;
        this.output = saved;

        this.emit("define " + ret_llvm + " @" + func_name + "(" + param_str + ") {");
        this.emit("entry:");
        var ai: int = 0;
        while (ai < this.entry_allocas.length) {
            this.output.push(this.entry_allocas[ai]);
            ai = ai + 1;
        };
        var bi: int = 0;
        while (bi < body_lines.length) {
            this.output.push(body_lines[bi]);
            bi = bi + 1;
        };
        this.emit("}");
        this.emitBlank();
    };

    // --------------------------------------------------------
    // genFunction
    // --------------------------------------------------------

    function genFunction(node: ASTNode) -> null {
        // Native function — register and emit declare only
        if (node.flag2) {
            var ret_llvm: str = this.toLLVMType(node.type_str);
            var param_str: str = "";
            var pi: int = 0;
            while (pi < node.params.length) {
                var p: ASTNode = node.params[pi];
                if (p.value == "didLoad") { pi = pi + 1; continue; };
                if (pi > 0 && param_str != "") { param_str = param_str + ", "; };
                param_str = param_str + this.toLLVMParamType(p.type_str);
                pi = pi + 1;
            };
            var decl: str = "declare " + ret_llvm + " @" + node.extra + "(" + param_str + ")";
            var already: bool = false;
            var di: int = 0;
            while (di < this.extra_declares.length) {
                if (this.extra_declares[di] == decl) { already = true; };
                di = di + 1;
            };
            if (already == false) {
                this.extra_declares.push(decl);
            };
            // register mocha name -> c name
            this.lib_functions.put(node.value, node.extra + "|" + ret_llvm);
            this.method_return_types.put(node.value, ret_llvm);
            this.method_return_types.put(node.extra, ret_llvm);
            return;
        };

        var ret_llvm: str = this.toLLVMType(node.type_str);

        // Build param string
        var param_str: str = "";
        if (this.current_class != "" && node.flag1 == false) {
            // instance method — prepend this
            param_str = "%struct." + this.current_class + "* %this";
        };
        var pi2: int = 0;
        while (pi2 < node.params.length) {
            var p2: ASTNode = node.params[pi2];
            if (p2.value == "didLoad") { pi2 = pi2 + 1; continue; };
            if (param_str != "") { param_str = param_str + ", "; };
            param_str = param_str + this.toLLVMParamType(p2.type_str) + " %" + p2.value;
            pi2 = pi2 + 1;
        };

        this.method_return_types.put(node.value, ret_llvm);

        var prev_return:  str  = this.current_return_type;
        var prev_in_func: bool = this.in_function;
        this.current_return_type = ret_llvm;
        this.in_function         = true;

        // Save locals
        var prev_ptrs:   HashTable = this.local_ptrs;
        var prev_types:  HashTable = this.local_types;
        var prev_mocha:  HashTable = this.local_mocha_types;
        var prev_counts: HashTable = this.local_name_counts;
        this.local_ptrs        = HashTable();
        this.local_types       = HashTable();
        this.local_mocha_types = HashTable();
        this.local_name_counts = HashTable();

        var saved: str[] = this.beginFunctionBody();

        // Store this
        if (this.current_class != "" && node.flag1 == false) {
            var this_type: str = "%struct." + this.current_class + "*";
            var this_ptr:  str = "%this.ptr";
            this.entry_allocas.push("  " + this_ptr + " = alloca " + this_type);
            this.emit("  store " + this_type + " %this, " + this_type + "* " + this_ptr);
            this.local_ptrs.put("this", this_ptr);
            this.local_types.put("this", this_type);
            this.local_mocha_types.put("this", this.current_class);
        };

        // Store params
        var pi3: int = 0;
        while (pi3 < node.params.length) {
            var p3: ASTNode = node.params[pi3];
            if (p3.value == "didLoad") { pi3 = pi3 + 1; continue; };
            var pt:  str = this.toLLVMParamType(p3.type_str);
            var ptr: str = "%" + p3.value + ".ptr";
            this.entry_allocas.push("  " + ptr + " = alloca " + pt);
            this.emit("  store " + pt + " %" + p3.value + ", " + pt + "* " + ptr);
            this.local_ptrs.put(p3.value, ptr);
            this.local_types.put(p3.value, pt);
            this.local_mocha_types.put(p3.value, p3.type_str);
            pi3 = pi3 + 1;
        };

        // Body
        var bi: int = 0;
        while (bi < node.body.length) {
            this.genStmt(node.body[bi]);
            bi = bi + 1;
        };

        var mangled: str = this.mangleName(node.value);
        this.endFunctionBody(saved, ret_llvm, mangled, param_str);

        // Restore
        this.current_return_type = prev_return;
        this.in_function         = prev_in_func;
        this.local_ptrs          = prev_ptrs;
        this.local_types         = prev_types;
        this.local_mocha_types   = prev_mocha;
        this.local_name_counts   = prev_counts;
        this.entry_allocas       = [];
    };

    // --------------------------------------------------------
    // genClass
    // --------------------------------------------------------

    function genClass(node: ASTNode) -> null {
        // Register inheritance
        if (node.children.length > 0) {
            this.class_parents.put(node.value, node.children[0].value);
        };

        // Register fields
        this.registerClassFields(node.value, node.body);

        // Also collect parent fields
        if (node.children.length > 0) {
            var parent_name: str = node.children[0].value;
            if (this.class_fields.has(parent_name)) {
                var parent_encoded: str = this.class_fields.get(parent_name);
                var child_encoded:  str = this.class_fields.get(node.value);
                if (parent_encoded != "" && child_encoded != "") {
                    this.class_fields.put(node.value, parent_encoded + "," + child_encoded);
                } else if (parent_encoded != "") {
                    this.class_fields.put(node.value, parent_encoded);
                };
            };
        };

        var prev_class: str = this.current_class;
        this.current_class = node.value;

        // Pre-register all method return types
        var mi: int = 0;
        while (mi < node.body.length) {
            var member: ASTNode = node.body[mi];
            if (member.kind == "MethodDecl") {
                var mangled_name: str = node.value + "_" + member.value;
                this.method_return_types.put(mangled_name, this.toLLVMType(member.type_str));
                if (member.value == "constructor") {
                    this.classes_with_ctors.push(node.value);
                };
            };
            mi = mi + 1;
        };

        // Generate methods
        var mj: int = 0;
        while (mj < node.body.length) {
            var member2: ASTNode = node.body[mj];
            if (member2.kind == "MethodDecl") {
                var orig_name: str = member2.value;
                member2.value = node.value + "_" + orig_name;
                this.genFunction(member2);
                member2.value = orig_name;
            };
            mj = mj + 1;
        };

        // Emit struct type declaration
        var fields_encoded: str = "";
        if (this.class_fields.has(node.value)) {
            fields_encoded = this.class_fields.get(node.value);
        };
        var field_list: str[] = splitComma(fields_encoded);
        var type_list: str = "";
        var fi: int = 0;
        while (fi < field_list.length) {
            if (fi > 0) { type_list = type_list + ", "; };
            type_list = type_list + this.fieldType(field_list[fi]);
            fi = fi + 1;
        };
        this.type_declarations.push("%struct." + node.value + " = type { " + type_list + " }");

        // Inheritance delegation wrappers
        if (node.children.length > 0) {
            var parent: str = node.children[0].value;
            this.emitInheritanceDelegations(node, parent);
        };

        this.current_class = prev_class;
    };

    function emitInheritanceDelegations(node: ASTNode, parent_name: str) -> null {
        // Find parent node
        var parent_idx: int = -1;
        var pi: int = 0;
        while (pi < this.class_node_list.length) {
            var key: str = this.class_node_index.get(this.class_node_list[pi].value);
            if (this.class_node_list[pi].value == parent_name) {
                parent_idx = pi;
            };
            pi = pi + 1;
        };
        if (parent_idx < 0) { return; };
        var parent_node: ASTNode = this.class_node_list[parent_idx];

        // Collect own method names
        var own_methods: str[] = [];
        var oi: int = 0;
        while (oi < node.body.length) {
            if (node.body[oi].kind == "MethodDecl") {
                own_methods.push(node.body[oi].value);
            };
            oi = oi + 1;
        };

        // For each parent method not overridden, emit delegation wrapper
        var pmi: int = 0;
        while (pmi < parent_node.body.length) {
            var pmember: ASTNode = parent_node.body[pmi];
            if (pmember.kind == "MethodDecl") {
                if (pmember.value == "constructor") { pmi = pmi + 1; continue; };

                // Check if overridden
                var overridden: bool = false;
                var oi2: int = 0;
                while (oi2 < own_methods.length) {
                    if (own_methods[oi2] == pmember.value) { overridden = true; };
                    oi2 = oi2 + 1;
                };
                if (overridden) { pmi = pmi + 1; continue; };

                var child_func:  str = node.value + "_" + pmember.value;
                var parent_func: str = parent_name + "_" + pmember.value;
                var ret_type:    str = this.toLLVMType(pmember.type_str);
                this.method_return_types.put(child_func, ret_type);

                var params_str: str = "%struct." + node.value + "* %self";
                var ppi: int = 0;
                while (ppi < pmember.params.length) {
                    var pp: ASTNode = pmember.params[ppi];
                    params_str = params_str + ", " + this.toLLVMParamType(pp.type_str) + " %" + pp.value;
                    ppi = ppi + 1;
                };

                var cast: str = this.freshTemp();
                if (ret_type == "void") {
                    this.emit("define void @" + child_func + "(" + params_str + ") {");
                    this.emit("entry:");
                    this.emit("  " + cast + " = bitcast %struct." + node.value + "* %self to %struct." + parent_name + "*");
                    var args_str: str = "%struct." + parent_name + "* " + cast;
                    var ppi2: int = 0;
                    while (ppi2 < pmember.params.length) {
                        var pp2: ASTNode = pmember.params[ppi2];
                        args_str = args_str + ", " + this.toLLVMParamType(pp2.type_str) + " %" + pp2.value;
                        ppi2 = ppi2 + 1;
                    };
                    this.emit("  call void @" + parent_func + "(" + args_str + ")");
                    this.emit("  ret void");
                } else {
                    this.emit("define " + ret_type + " @" + child_func + "(" + params_str + ") {");
                    this.emit("entry:");
                    this.emit("  " + cast + " = bitcast %struct." + node.value + "* %self to %struct." + parent_name + "*");
                    var args_str2: str = "%struct." + parent_name + "* " + cast;
                    var ppi3: int = 0;
                    while (ppi3 < pmember.params.length) {
                        var pp3: ASTNode = pmember.params[ppi3];
                        args_str2 = args_str2 + ", " + this.toLLVMParamType(pp3.type_str) + " %" + pp3.value;
                        ppi3 = ppi3 + 1;
                    };
                    var tmp: str = this.freshTemp();
                    this.emit("  " + tmp + " = call " + ret_type + " @" + parent_func + "(" + args_str2 + ")");
                    this.emit("  ret " + ret_type + " " + tmp);
                };
                this.emit("}");
                this.emitBlank();
            };
            pmi = pmi + 1;
        };
    };

    // --------------------------------------------------------
    // genExtend
    // --------------------------------------------------------

    function genExtend(node: ASTNode) -> null {
        var type_to_llvm: HashTable = HashTable();
        type_to_llvm.put("str",      "i8*");
        type_to_llvm.put("int",      "i32");
        type_to_llvm.put("vast",     "i64");
        type_to_llvm.put("float",    "double");
        type_to_llvm.put("bool",     "i8");
        type_to_llvm.put("int[]",    "%MochaArray*");
        type_to_llvm.put("float[]",  "%MochaArray*");
        type_to_llvm.put("str[]",    "%MochaArray*");
        type_to_llvm.put("bool[]",   "%MochaArray*");
        type_to_llvm.put("vast[]",   "%MochaArray*");
        type_to_llvm.put("int[][]",  "%MochaArray2D*");
        type_to_llvm.put("float[][]","%MochaArray2D*");

        var this_llvm: str = "";
        if (type_to_llvm.has(node.value)) {
            this_llvm = type_to_llvm.get(node.value);
        } else {
            this_llvm = "%struct." + node.value + "*";
        };

        var prev_class: str = this.current_class;
        this.current_class = node.value;

        var fi: int = 0;
        while (fi < node.body.length) {
            var func: ASTNode = node.body[fi];
            var method_name: str = "mocha_ext_" + this.sanitizeTypeName(node.value) + "_" + func.value;
            var ret_llvm: str = this.toLLVMType(func.type_str);
            this.method_return_types.put(method_name, ret_llvm);

            if (func.flag2) { fi = fi + 1; continue; }; // native

            var param_str: str = this_llvm + " %this";
            var pi: int = 0;
            while (pi < func.params.length) {
                var p: ASTNode = func.params[pi];
                param_str = param_str + ", " + this.toLLVMParamType(p.type_str) + " %" + p.value;
                pi = pi + 1;
            };

            var prev_return:  str  = this.current_return_type;
            var prev_in_func: bool = this.in_function;
            this.current_return_type = ret_llvm;
            this.in_function         = true;

            var prev_ptrs:   HashTable = this.local_ptrs;
            var prev_types:  HashTable = this.local_types;
            var prev_mocha:  HashTable = this.local_mocha_types;
            var prev_counts: HashTable = this.local_name_counts;
            this.local_ptrs        = HashTable();
            this.local_types       = HashTable();
            this.local_mocha_types = HashTable();
            this.local_name_counts = HashTable();

            var saved: str[] = this.beginFunctionBody();

            // Store this
            var this_ptr: str = "%this.ptr";
            this.entry_allocas.push("  " + this_ptr + " = alloca " + this_llvm);
            this.emit("  store " + this_llvm + " %this, " + this_llvm + "* " + this_ptr);
            this.local_ptrs.put("this", this_ptr);
            this.local_types.put("this", this_llvm);
            this.local_mocha_types.put("this", node.value);

            // Store params
            var pi2: int = 0;
            while (pi2 < func.params.length) {
                var p2: ASTNode = func.params[pi2];
                var pt:  str = this.toLLVMParamType(p2.type_str);
                var ptr: str = "%" + p2.value + ".ptr";
                this.entry_allocas.push("  " + ptr + " = alloca " + pt);
                this.emit("  store " + pt + " %" + p2.value + ", " + pt + "* " + ptr);
                this.local_ptrs.put(p2.value, ptr);
                this.local_types.put(p2.value, pt);
                this.local_mocha_types.put(p2.value, p2.type_str);
                pi2 = pi2 + 1;
            };

            var bi: int = 0;
            while (bi < func.body.length) {
                this.genStmt(func.body[bi]);
                bi = bi + 1;
            };

            this.endFunctionBody(saved, ret_llvm, method_name, param_str);

            this.current_return_type = prev_return;
            this.in_function         = prev_in_func;
            this.local_ptrs          = prev_ptrs;
            this.local_types         = prev_types;
            this.local_mocha_types   = prev_mocha;
            this.local_name_counts   = prev_counts;
            this.entry_allocas       = [];

            fi = fi + 1;
        };

        this.current_class = prev_class;
    };

    // --------------------------------------------------------
    // genTagDecl
    // --------------------------------------------------------

    function genTagDecl(node: ASTNode) -> null {
        this.tag_types.push(node.value);

        // Emit each member as a global i32 constant
        var i: int = 0;
        while (i < node.children.length) {
            var member: str = node.children[i].value;
            var gname:  str = "@" + node.value + "__" + member;
            this.emit(gname + " = constant i32 " + str(i));
            this.global_ptrs.put(node.value + "." + member, gname);
            this.global_mocha_types.put(node.value + "." + member, node.value);
            i = i + 1;
        };

        // Emit .name() lookup function
        this.emit("define i8* @" + node.value + "__name(i32 %v) {");
        this.emit("entry:");
        this.emit("  switch i32 %v, label %tag_default [");
        var j: int = 0;
        while (j < node.children.length) {
            this.emit("    i32 " + str(j) + ", label %tag_case" + str(j));
            j = j + 1;
        };
        this.emit("  ]");
        var k: int = 0;
        while (k < node.children.length) {
            var mname:  str = node.children[k].value;
            var gname2: str = this.freshStrGlobal(mname);
            var mlen:   int = mname.length + 1;
            this.emit("tag_case" + str(k) + ":");
            this.emit("  ret i8* getelementptr inbounds ([" + str(mlen) + " x i8], [" + str(mlen) + " x i8]* " + gname2 + ", i32 0, i32 0)");
            k = k + 1;
        };
        var unk_gname: str = this.freshStrGlobal("unknown");
        this.emit("tag_default:");
        this.emit("  ret i8* getelementptr inbounds ([8 x i8], [8 x i8]* " + unk_gname + ", i32 0, i32 0)");
        this.emit("}");
        this.emitBlank();
    };

    // --------------------------------------------------------
    // genImport — register lib functions from manifests
    // --------------------------------------------------------

    function genImport(node: ASTNode) -> null {
        // imports are handled at a higher level
        // lib_functions get populated during the pre-pass
    };
};