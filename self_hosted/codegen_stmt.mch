// mocha-lib-deps: mocha-string
// ============================================================
// codegen_stmt.mch — Statement code generation
// ============================================================

extend CodeGen {

    // --------------------------------------------------------
    // Helper: convert bool (i8/i1) to i1 for branching
    // --------------------------------------------------------

    function boolToI1(reg: str, typ: str) -> str {
        if (typ == "i1") { return reg; };
        var tmp: str = this.freshTemp();
        if (typ == "i8") {
            this.emit("  " + tmp + " = icmp ne i8 " + reg + ", 0");
            return tmp;
        };
        if (typ == "i32") {
            this.emit("  " + tmp + " = icmp ne i32 " + reg + ", 0");
            return tmp;
        };
        this.emit("  " + tmp + " = icmp ne i8 " + reg + ", 0");
        return tmp;
    };

    // Helper: emit unconditional branch only if block not yet terminated
    function emitBrIfNeeded(label: str) -> null {
        // check last emitted line
        if (this.output.length == 0) {
            this.emit("  br label %" + label);
            return;
        };
        var last: str = this.output[this.output.length - 1];
        // if last instruction is a terminator, don't emit br
        if (last.contains("ret ") || last.contains("br ") ||
            last.contains("unreachable")) {
            return;
        };
        this.emit("  br label %" + label);
    };

    // Helper: alloca at entry — emit into entry_allocas list
    function allocaAtEntry(llvm_type: str) -> str {
        var ptr: str = this.freshTemp();
        this.entry_allocas.push("  " + ptr + " = alloca " + llvm_type);
        return ptr;
    };

    // Helper: coerce val_reg/val_type to match target llvm_type
    function coerceToType(val_reg: str, val_type: str, llvm_type: str) -> str {
        if (val_type == llvm_type) { return val_reg; };

        var tmp: str = this.freshTemp();

        // i1 -> i8
        if (val_type == "i1" && llvm_type == "i8") {
            this.emit("  " + tmp + " = zext i1 " + val_reg + " to i8");
            return tmp;
        };
        // i8 -> i32
        if (val_type == "i8" && llvm_type == "i32") {
            this.emit("  " + tmp + " = zext i8 " + val_reg + " to i32");
            return tmp;
        };
        // i8 -> double
        if (val_type == "i8" && llvm_type == "double") {
            var mid: str = this.freshTemp();
            this.emit("  " + mid + " = zext i8 " + val_reg + " to i32");
            this.emit("  " + tmp + " = uitofp i32 " + mid + " to double");
            return tmp;
        };
        // i32 -> double
        if (val_type == "i32" && llvm_type == "double") {
            this.emit("  " + tmp + " = sitofp i32 " + val_reg + " to double");
            return tmp;
        };
        // i32 -> i64
        if (val_type == "i32" && llvm_type == "i64") {
            this.emit("  " + tmp + " = sext i32 " + val_reg + " to i64");
            return tmp;
        };
        // i64 -> i32
        if (val_type == "i64" && llvm_type == "i32") {
            this.emit("  " + tmp + " = trunc i64 " + val_reg + " to i32");
            return tmp;
        };
        // i64 -> double
        if (val_type == "i64" && llvm_type == "double") {
            this.emit("  " + tmp + " = sitofp i64 " + val_reg + " to double");
            return tmp;
        };
        // i64 -> i8
        if (val_type == "i64" && llvm_type == "i8") {
            this.emit("  " + tmp + " = trunc i64 " + val_reg + " to i8");
            return tmp;
        };
        // i32 -> pointer
        if (val_type == "i32" && llvm_type.charAt(llvm_type.length - 1) == "*") {
            this.emit("  " + tmp + " = inttoptr i32 " + val_reg + " to " + llvm_type);
            return tmp;
        };
        // i8 -> i8* (inttoptr)
        if (val_type == "i8" && llvm_type == "i8*") {
            this.emit("  " + tmp + " = inttoptr i8 " + val_reg + " to i8*");
            return tmp;
        };
        // bitcast as fallback for pointer types
        if (val_type.charAt(val_type.length - 1) == "*" &&
            llvm_type.charAt(llvm_type.length - 1) == "*") {
            this.emit("  " + tmp + " = bitcast " + val_type + " " + val_reg + " to " + llvm_type);
            return tmp;
        };
        return val_reg;
    };

    // --------------------------------------------------------
    // genStmt — main dispatcher
    // --------------------------------------------------------

    function genStmt(node: ASTNode) -> null {
        match (node.kind) {
            case "VarDecl":
                this.genVarDecl(node);
            case "ConstDecl":
                this.genConstDecl(node);
            case "Assignment":
                this.genAssignment(node);
            case "CompoundAssignment":
                this.genCompoundAssignmentStmt(node);
            case "ReturnStmt":
                this.genReturn(node);
            case "IfStmt":
                this.genIf(node);
            case "WhileLoop":
                this.genWhile(node);
            case "ForLoop":
                this.genFor(node);
            case "ForEachLoop":
                this.genForeach(node);
            case "MatchStmt":
                this.genMatch(node);
            case "BreakStmt":
                this.emit("  br label %" + this.break_label);
            case "ContinueStmt":
                this.emit("  br label %" + this.continue_label);
            case "PrintStmt":
                this.genPrint(node);
            case "ExprStmt":
                this.genExpr(node.left);
            case "FunctionCall":
                this.genFunctionCall(node);
            case "PostIncrement":
                this.genPostIncrement(node);
            case "PreIncrement":
                this.genPreIncrement(node);
            case "PreDecrement":
                this.genPreDecrement(node);
            default:
                this.genExpr(node);
        };
    };

    // --------------------------------------------------------
    // VarDecl
    // --------------------------------------------------------

    function genVarDecl(node: ASTNode) -> null {
        var mocha_type: str = node.type_str;
        var name:       str = node.value;
        var ptr_name:   str = "%" + this.uniquePtrName(name) + ".ptr";

        // Tuple
        if (mocha_type.charAt(0) == "(") {
            var val_result: str = this.genExpr(node.left);
            var val_reg:    str = this.exprReg(val_result);
            this.emit("  " + ptr_name + " = alloca %MochaTuple*");
            this.emit("  store %MochaTuple* " + val_reg + ", %MochaTuple** " + ptr_name);
            this.declareLocal(name, ptr_name, "%MochaTuple*", mocha_type);
            return;
        };

        // Arrays
        if (mocha_type.contains("[][]")) {
            var val_result: str = this.genExpr(node.left);
            var val_reg:    str = this.exprReg(val_result);
            this.emit("  " + ptr_name + " = alloca %MochaArray2D*");
            this.emit("  store %MochaArray2D* " + val_reg + ", %MochaArray2D** " + ptr_name);
            this.declareLocal(name, ptr_name, "%MochaArray2D*", mocha_type);
            return;
        };
        if (mocha_type.contains("[")) {
            var val_result: str = this.genExpr(node.left);
            var val_reg:    str = this.exprReg(val_result);
            this.emit("  " + ptr_name + " = alloca %MochaArray*");
            this.emit("  store %MochaArray* " + val_reg + ", %MochaArray** " + ptr_name);
            this.declareLocal(name, ptr_name, "%MochaArray*", mocha_type);
            return;
        };

        // HashTable
        if (mocha_type == "HashTable") {
            var val_result: str = this.genExpr(node.left);
            var val_reg:    str = this.exprReg(val_result);
            this.emit("  " + ptr_name + " = alloca %struct.MochaHashTable*");
            this.emit("  store %struct.MochaHashTable* " + val_reg + ", %struct.MochaHashTable** " + ptr_name);
            this.declareLocal(name, ptr_name, "%struct.MochaHashTable*", mocha_type);
            return;
        };

        // Dict
        if (mocha_type == "dict") {
            var val_result: str = this.genExpr(node.left);
            var val_reg:    str = this.exprReg(val_result);
            this.emit("  " + ptr_name + " = alloca %MochaDict*");
            this.emit("  store %MochaDict* " + val_reg + ", %MochaDict** " + ptr_name);
            this.declareLocal(name, ptr_name, "%MochaDict*", mocha_type);
            return;
        };

        // User class / struct
        var llvm_type: str = this.toLLVMType(mocha_type);
        if (llvm_type.length >= 8) {
            if (llvm_type.substring(0, 7) == "%struct") {
                var val_result: str = this.genExpr(node.left);
                var val_reg:    str = this.exprReg(val_result);
                this.emit("  " + ptr_name + " = alloca " + llvm_type);
                this.emit("  store " + llvm_type + " " + val_reg + ", " + llvm_type + "* " + ptr_name);
                this.declareLocal(name, ptr_name, llvm_type, mocha_type);
                return;
        };
        };

        // Primitives: int/float/bool/str/vast/null
        var val_result: str = "";
        var val_reg:    str = "";
        var val_type:   str = "";

        if (node.left != null) {
            val_result = this.genExpr(node.left);
            val_reg    = this.exprReg(val_result);
            val_type   = this.exprType(val_result);
        };

        this.emit("  " + ptr_name + " = alloca " + llvm_type);

        if (val_reg == "" || val_reg == "void" || val_type == "void") {
            // no initializer or void result
            if (llvm_type.charAt(llvm_type.length - 1) == "*") {
                this.emit("  store " + llvm_type + " null, " + llvm_type + "* " + ptr_name);
            } else if (llvm_type == "double") {
                this.emit("  store double 0.0, double* " + ptr_name);
            } else {
                this.emit("  store " + llvm_type + " 0, " + llvm_type + "* " + ptr_name);
            };
        } else {
            var coerced: str = this.coerceToType(val_reg, val_type, llvm_type);
            this.emit("  store " + llvm_type + " " + coerced + ", " + llvm_type + "* " + ptr_name);
        };

        this.declareLocal(name, ptr_name, llvm_type, mocha_type);
    };

    // --------------------------------------------------------
    // ConstDecl
    // --------------------------------------------------------

    function genConstDecl(node: ASTNode) -> null {
        // Simple literal constants stored in lib_constants
        if (node.left.kind == "IntLiteral") {
            this.lib_functions.put(node.value, str(node.left.int_val) + "|i32");
            return;
        };
        if (node.left.kind == "FloatLiteral") {
            this.lib_functions.put(node.value, str(node.left.real_val) + "|double");
            return;
        };
        if (node.left.kind == "BoolLiteral") {
            var v: int = 0;
            if (node.left.bool_val) { v = 1; };
            this.lib_functions.put(node.value, str(v) + "|i8");
            return;
        };
        // Complex const — treat as var
        this.genVarDecl(node);
    };

    // --------------------------------------------------------
    // Assignment
    // --------------------------------------------------------

    function genAssignment(node: ASTNode) -> null {
        var val_result: str = this.genExpr(node.right);
        var val_reg:    str = this.exprReg(val_result);
        var val_type:   str = this.exprType(val_result);

        // Identifier assignment
        if (node.left.kind == "Identifier") {
            if (this.hasLocal(node.left.value) == false) {
                mocha_error("MochaCodeGenError", "Assignment to undeclared variable '" + node.left.value + "'");
                return;
            };
            var ptr:      str = this.getLocalPtr(node.left.value);
            var llvm_type: str = this.getLocalType(node.left.value);
            var coerced:  str = this.coerceToType(val_reg, val_type, llvm_type);
            this.emit("  store " + llvm_type + " " + coerced + ", " + llvm_type + "* " + ptr);
            return;
        };

        // Member assignment: this.field = value or obj.field = value
        if (node.left.kind == "MemberAccess") {
            var obj_result: str = this.genExpr(node.left.left);
            var obj_reg:    str = this.exprReg(obj_result);
            var obj_type:   str = this.exprType(obj_result);
            if (obj_type.length < 8) { return; };
            if (obj_type.substring(0, 7) != "%struct") { return; };
            var class_name: str = this.inferClassName(obj_type);
            var field_idx:  int = this.getFieldIndex(class_name, node.left.value);
            var field_type: str = this.getFieldLLVMType(class_name, node.left.value);
            if (field_idx < 0) { return; };
            var struct_type: str = "%struct." + class_name;
            var gep: str = this.freshTemp();
            this.emit("  " + gep + " = getelementptr " + struct_type + ", " + obj_type + " " + obj_reg + ", i32 0, i32 " + str(field_idx));
            var coerced: str = this.coerceToType(val_reg, val_type, field_type);
            this.emit("  store " + field_type + " " + coerced + ", " + field_type + "* " + gep);
            return;
        };

        // Index assignment: arr[i] = value
        if (node.left.kind == "IndexAccess") {
            var arr_result: str = this.genExpr(node.left.left);
            var arr_reg:    str = this.exprReg(arr_result);
            var idx_result: str = this.genExpr(node.left.right);
            var idx_reg:    str = this.exprReg(idx_result);
            var slot:       str = this.allocaAtEntry(val_type);
            this.emit("  store " + val_type + " " + val_reg + ", " + val_type + "* " + slot);
            var cast: str = this.freshTemp();
            this.emit("  " + cast + " = bitcast " + val_type + "* " + slot + " to i8*");
            this.emit("  call void @mocha_array_set(%MochaArray* " + arr_reg + ", i32 " + idx_reg + ", i8* " + cast + ")");
            return;
        };

        // 2D index assignment: arr[r][c] = value
        if (node.left.kind == "Index2DAccess") {
            var arr2_result: str = this.genExpr(node.left.left);
            var arr2_reg:    str = this.exprReg(arr2_result);
            var row_result:  str = this.genExpr(node.left.condition);
            var row_reg:     str = this.exprReg(row_result);
            var col_result:  str = this.genExpr(node.left.right);
            var col_reg:     str = this.exprReg(col_result);
            var slot2:       str = this.allocaAtEntry(val_type);
            this.emit("  store " + val_type + " " + val_reg + ", " + val_type + "* " + slot2);
            var cast2: str = this.freshTemp();
            this.emit("  " + cast2 + " = bitcast " + val_type + "* " + slot2 + " to i8*");
            this.emit("  call void @mocha_array2d_set(%MochaArray2D* " + arr2_reg + ", i32 " + row_reg + ", i32 " + col_reg + ", i8* " + cast2 + ")");
            return;
        };
    };

    // --------------------------------------------------------
    // CompoundAssignment (stmt version)
    // --------------------------------------------------------

    function genCompoundAssignmentStmt(node: ASTNode) -> null {
        // reuse the expr codegen — it handles this.field += x now
        this.genExpr(node);
    };

    // --------------------------------------------------------
    // Return
    // --------------------------------------------------------

    function genReturn(node: ASTNode) -> null {
        if (node.left == null) {
            this.emit("  ret void");
            return;
        };
        var val_result: str = this.genExpr(node.left);
        var val_reg:    str = this.exprReg(val_result);
        var val_type:   str = this.exprType(val_result);
        var ret_type:   str = this.current_return_type;

        if (ret_type == "void") {
            this.emit("  ret void");
            return;
        };

        var coerced: str = this.coerceToType(val_reg, val_type, ret_type);
        this.emit("  ret " + ret_type + " " + coerced);
    };

    // --------------------------------------------------------
    // If
    // --------------------------------------------------------

    function genIf(node: ASTNode) -> null {
        var count:    int = this.temp_count;
        var then_lbl: str = "if_then_" + str(count);
        var else_lbl: str = "if_else_" + str(count);
        var end_lbl:  str = "if_end_"  + str(count);
        this.temp_count = this.temp_count + 1;

        var cond_result: str = this.genExpr(node.condition);
        var cond_reg:    str = this.exprReg(cond_result);
        var cond_type:   str = this.exprType(cond_result);
        var cond_i1:     str = this.boolToI1(cond_reg, cond_type);

        if (node.else_body.length > 0 || node.else_ifs.length > 0) {
            this.emit("  br i1 " + cond_i1 + ", label %" + then_lbl + ", label %" + else_lbl);
        } else {
            this.emit("  br i1 " + cond_i1 + ", label %" + then_lbl + ", label %" + end_lbl);
        };

        this.emit(then_lbl + ":");
        var bi: int = 0;
        while (bi < node.body.length) {
            this.genStmt(node.body[bi]);
            bi = bi + 1;
        };
        this.emitBrIfNeeded(end_lbl);

        // else-ifs
        if (node.else_ifs.length > 0) {
            this.emit(else_lbl + ":");
            var ei: int = 0;
            while (ei < node.else_ifs.length) {
                var elif_node:   ASTNode = node.else_ifs[ei];
                var ec_result:   str     = this.genExpr(elif_node.condition);
                var ec_reg:      str     = this.exprReg(ec_result);
                var ec_type:     str     = this.exprType(ec_result);
                var ec_i1:       str     = this.boolToI1(ec_reg, ec_type);
                var elif_then:   str     = "elif_then_" + str(count) + "_" + str(ei);
                var elif_else:   str     = "elif_else_" + str(count) + "_" + str(ei);
                this.emit("  br i1 " + ec_i1 + ", label %" + elif_then + ", label %" + elif_else);
                this.emit(elif_then + ":");
                var ebi: int = 0;
                while (ebi < elif_node.body.length) {
                    this.genStmt(elif_node.body[ebi]);
                    ebi = ebi + 1;
                };
                this.emitBrIfNeeded(end_lbl);
                this.emit(elif_else + ":");
                ei = ei + 1;
            };
            if (node.else_body.length > 0) {
                var eli: int = 0;
                while (eli < node.else_body.length) {
                    this.genStmt(node.else_body[eli]);
                    eli = eli + 1;
                };
            };
            this.emitBrIfNeeded(end_lbl);
        } else if (node.else_body.length > 0) {
            this.emit(else_lbl + ":");
            var eli2: int = 0;
            while (eli2 < node.else_body.length) {
                this.genStmt(node.else_body[eli2]);
                eli2 = eli2 + 1;
            };
            this.emitBrIfNeeded(end_lbl);
        };

        this.emit(end_lbl + ":");
    };

    // --------------------------------------------------------
    // While
    // --------------------------------------------------------

    function genWhile(node: ASTNode) -> null {
        var count:    int = this.temp_count;
        var cond_lbl: str = "while_cond_" + str(count);
        var body_lbl: str = "while_body_" + str(count);
        var end_lbl:  str = "while_end_"  + str(count);
        this.temp_count = this.temp_count + 1;

        var prev_break:    str = this.break_label;
        var prev_continue: str = this.continue_label;
        this.break_label    = end_lbl;
        this.continue_label = cond_lbl;

        this.emit("  br label %" + cond_lbl);
        this.emit(cond_lbl + ":");
        var cond_result: str = this.genExpr(node.condition);
        var cond_i1:     str = this.boolToI1(this.exprReg(cond_result), this.exprType(cond_result));
        this.emit("  br i1 " + cond_i1 + ", label %" + body_lbl + ", label %" + end_lbl);
        this.emit(body_lbl + ":");
        var i: int = 0;
        while (i < node.body.length) {
            this.genStmt(node.body[i]);
            i = i + 1;
        };
        this.emitBrIfNeeded(cond_lbl);
        this.emit(end_lbl + ":");

        this.break_label    = prev_break;
        this.continue_label = prev_continue;
    };

    // --------------------------------------------------------
    // For
    // --------------------------------------------------------

    function genFor(node: ASTNode) -> null {
        var count:    int = this.temp_count;
        var cond_lbl: str = "for_cond_" + str(count);
        var body_lbl: str = "for_body_" + str(count);
        var end_lbl:  str = "for_end_"  + str(count);
        this.temp_count = this.temp_count + 1;

        var prev_break:    str = this.break_label;
        var prev_continue: str = this.continue_label;
        this.break_label    = end_lbl;
        this.continue_label = cond_lbl;

        this.genStmt(node.left); // init
        this.emit("  br label %" + cond_lbl);
        this.emit(cond_lbl + ":");
        var cond_result: str = this.genExpr(node.condition);
        var cond_i1:     str = this.boolToI1(this.exprReg(cond_result), this.exprType(cond_result));
        this.emit("  br i1 " + cond_i1 + ", label %" + body_lbl + ", label %" + end_lbl);
        this.emit(body_lbl + ":");
        var i: int = 0;
        while (i < node.body.length) {
            this.genStmt(node.body[i]);
            i = i + 1;
        };
        this.genExpr(node.right); // step
        this.emitBrIfNeeded(cond_lbl);
        this.emit(end_lbl + ":");

        this.break_label    = prev_break;
        this.continue_label = prev_continue;
    };

    // --------------------------------------------------------
    // ForEach
    // --------------------------------------------------------

    function genForeach(node: ASTNode) -> null {
        var count:    int = this.temp_count;
        var cond_lbl: str = "foreach_cond_" + str(count);
        var body_lbl: str = "foreach_body_" + str(count);
        var end_lbl:  str = "foreach_end_"  + str(count);
        this.temp_count = this.temp_count + 1;

        var arr_result: str = this.genExpr(node.left);
        var arr_reg:    str = this.exprReg(arr_result);

        var len_tmp: str = this.freshTemp();
        this.emit("  " + len_tmp + " = call i32 @mocha_array_length(%MochaArray* " + arr_reg + ")");

        var idx_ptr: str = this.freshTemp();
        this.emit("  " + idx_ptr + " = alloca i32");
        this.emit("  store i32 0, i32* " + idx_ptr);

        var prev_break:    str = this.break_label;
        var prev_continue: str = this.continue_label;
        this.break_label    = end_lbl;
        this.continue_label = cond_lbl;

        this.emit("  br label %" + cond_lbl);
        this.emit(cond_lbl + ":");

        var idx_tmp: str = this.freshTemp();
        var cmp_tmp: str = this.freshTemp();
        this.emit("  " + idx_tmp + " = load i32, i32* " + idx_ptr);
        this.emit("  " + cmp_tmp + " = icmp slt i32 " + idx_tmp + ", " + len_tmp);
        this.emit("  br i1 " + cmp_tmp + ", label %" + body_lbl + ", label %" + end_lbl);
        this.emit(body_lbl + ":");

        var var_mocha_type: str = node.type_str;
        if (var_mocha_type == "") { var_mocha_type = "str"; };
        var llvm_type: str = this.toLLVMType(var_mocha_type);
        var elem_ptr:  str = this.freshTemp();
        var elem_tmp:  str = this.freshTemp();
        this.emit("  " + elem_ptr + " = alloca " + llvm_type);
        this.emit("  call void @mocha_array_get(%MochaArray* " + arr_reg + ", i32 " + idx_tmp + ", i8* " + elem_ptr + ")");
        this.emit("  " + elem_tmp + " = load " + llvm_type + ", " + llvm_type + "* " + elem_ptr);

        var var_ptr: str = "%" + node.value + "_" + str(count) + ".ptr";
        this.emit("  " + var_ptr + " = alloca " + llvm_type);
        this.emit("  store " + llvm_type + " " + elem_tmp + ", " + llvm_type + "* " + var_ptr);
        this.declareLocal(node.value, var_ptr, llvm_type, var_mocha_type);

        var i: int = 0;
        while (i < node.body.length) {
            this.genStmt(node.body[i]);
            i = i + 1;
        };

        var next_tmp: str = this.freshTemp();
        var idx_tmp2: str = this.freshTemp();
        this.emit("  " + idx_tmp2 + " = load i32, i32* " + idx_ptr);
        this.emit("  " + next_tmp + " = add i32 " + idx_tmp2 + ", 1");
        this.emit("  store i32 " + next_tmp + ", i32* " + idx_ptr);
        this.emitBrIfNeeded(cond_lbl);
        this.emit(end_lbl + ":");

        this.break_label    = prev_break;
        this.continue_label = prev_continue;
    };

    // --------------------------------------------------------
    // Match
    // --------------------------------------------------------

    function genMatch(node: ASTNode) -> null {
        var count:   int = this.temp_count;
        var end_lbl: str = "match_end_" + str(count);
        this.temp_count = this.temp_count + 1;

        var val_result: str = this.genExpr(node.left);
        var val_reg:    str = this.exprReg(val_result);
        var val_type:   str = this.exprType(val_result);

        // Separate regular and default cases
        var case_indices:   int[] = [];
        var default_indices: int[] = [];
        var ci: int = 0;
        while (ci < node.cases.length) {
            if (node.cases[ci].flag1) {
                default_indices.push(ci);
            } else {
                case_indices.push(ci);
            };
            ci = ci + 1;
        };

        // Jump to first case
        if (case_indices.length > 0) {
            this.emit("  br label %match_case_" + str(count) + "_" + str(case_indices[0]));
        } else if (default_indices.length > 0) {
            this.emit("  br label %match_default_" + str(count));
        } else {
            return;
        };

        var idx: int = 0;
        while (idx < case_indices.length) {
            var i:        int    = case_indices[idx];
            var case_node: ASTNode = node.cases[i];
            var case_lbl: str    = "match_case_" + str(count) + "_" + str(i);
            var next_lbl: str    = end_lbl;

            if (idx + 1 < case_indices.length) {
                next_lbl = "match_case_" + str(count) + "_" + str(case_indices[idx + 1]);
            } else if (default_indices.length > 0) {
                next_lbl = "match_default_" + str(count);
            };

            this.emit(case_lbl + ":");

            // Pattern with 'when' guard — identifier binding
            if (case_node.left != null) {
                if (case_node.left.kind == "Identifier" && case_node.condition != null) {
                    var body_lbl: str = "match_body_" + str(count) + "_" + str(i);
                    var bind_ptr: str = "%match_bind_" + case_node.left.value + "_" + str(count) + "_" + str(i);
                    this.emit("  " + bind_ptr + " = alloca " + val_type);
                    this.emit("  store " + val_type + " " + val_reg + ", " + val_type + "* " + bind_ptr);
                    this.declareLocal(case_node.left.value, bind_ptr, val_type, "unknown");
                    var wc_result: str = this.genExpr(case_node.condition);
                    var wc_i1:     str = this.boolToI1(this.exprReg(wc_result), this.exprType(wc_result));
                    this.emit("  br i1 " + wc_i1 + ", label %" + body_lbl + ", label %" + next_lbl);
                    this.emit(body_lbl + ":");
                    var wbi: int = 0;
                    while (wbi < case_node.body.length) {
                        this.genStmt(case_node.body[wbi]);
                        wbi = wbi + 1;
                    };
                    this.emitBrIfNeeded(end_lbl);
                    // remove binding
                    this.local_ptrs.remove(case_node.left.value);
                    this.local_types.remove(case_node.left.value);
                    this.local_mocha_types.remove(case_node.left.value);
                    idx = idx + 1;
                    continue;
                };

                // Normal pattern match
                var pat_result: str = this.genExpr(case_node.left);
                var pat_reg:    str = this.exprReg(pat_result);
                var cmp:        str = this.freshTemp();
                var body_lbl2:  str = "match_body_" + str(count) + "_" + str(i);

                if (val_type == "i8*") {
                    var eq: str = this.freshTemp();
                    this.emit("  " + eq + " = call i32 @mocha_str_eq(i8* " + val_reg + ", i8* " + pat_reg + ")");
                    this.emit("  " + cmp + " = icmp ne i32 " + eq + ", 0");
                } else {
                    this.emit("  " + cmp + " = icmp eq " + val_type + " " + val_reg + ", " + pat_reg);
                };

                this.emit("  br i1 " + cmp + ", label %" + body_lbl2 + ", label %" + next_lbl);
                this.emit(body_lbl2 + ":");
                var bi2: int = 0;
                while (bi2 < case_node.body.length) {
                    this.genStmt(case_node.body[bi2]);
                    bi2 = bi2 + 1;
                };
                this.emitBrIfNeeded(end_lbl);
            };

            idx = idx + 1;
        };

        // Default case
        var di: int = 0;
        while (di < default_indices.length) {
            this.emit("match_default_" + str(count) + ":");
            var def_node: ASTNode = node.cases[default_indices[di]];
            var dbi: int = 0;
            while (dbi < def_node.body.length) {
                this.genStmt(def_node.body[dbi]);
                dbi = dbi + 1;
            };
            this.emitBrIfNeeded(end_lbl);
            di = di + 1;
        };

        this.emit(end_lbl + ":");
    };
};