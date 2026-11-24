// mocha-lib-deps: mocha-string
// ============================================================
// codegen_expr.mch — Expression code generation
// ============================================================

// ============================================================
// String global helpers (part of CodeGen class extension)
// ============================================================

extend CodeGen {

    // --------------------------------------------------------
    // String global pool
    // freshStrGlobal interns a string and emits a global
    // --------------------------------------------------------

    function freshStrGlobal(s: str) -> str {
        var id: int = this.internString(s);
        var gname: str = "@.str" + str(id);
        return gname;
    };

    function emitStringGlobals() -> null {
        var i: int = 0;
        while (i < this.string_const_keys.length) {
            var s:    str = this.string_const_keys[i];
            var id:   int = this.string_const_ids[i];
            var len:  int = s.length + 1;
            var gname: str = "@.str" + str(id);
            // emit: @.str0 = private unnamed_addr constant [6 x i8] c"hello\00"
            var escaped: str = this.escapeStr(s);
            this.emit(gname + " = private unnamed_addr constant [" + str(len) + " x i8] c\"" + escaped + "\\00\"");
            i = i + 1;
        };
    };

    function escapeStr(s: str) -> str {
        var result: str = "";
        var i: int = 0;
        while (i < s.length) {
            var ch: str = s.charAt(i);
            if (ch == "\n") {
                result = result + "\\0A";
            } else if (ch == "\t") {
                result = result + "\\09";
            } else if (ch == "\"") {
                result = result + "\\22";
            } else if (ch == "\\") {
                result = result + "\\5C";
            } else {
                result = result + ch;
            };
            i = i + 1;
        };
        return result;
    };

    // --------------------------------------------------------
    // genExpr — main dispatcher
    // returns (reg, llvm_type) encoded as "reg|llvm_type"
    // --------------------------------------------------------

    function genExpr(node: ASTNode) -> str {
        match (node.kind) {
            case "IntLiteral":     return this.genIntLiteral(node);
            case "FloatLiteral":   return this.genFloatLiteral(node);
            case "BoolLiteral":    return this.genBoolLiteral(node);
            case "StrLiteral":     return this.genStrLiteral(node);
            case "NullLiteral":    return this.genNullLiteral(node);
            case "Identifier":     return this.genIdentifier(node);
            case "This":           return this.genThis(node);
            case "BinaryOp":       return this.genBinaryOp(node);
            case "UnaryOp":        return this.genUnaryOp(node);
            case "PreIncrement":   return this.genPreIncrement(node);
            case "PreDecrement":   return this.genPreDecrement(node);
            case "PostIncrement":  return this.genPostIncrement(node);
            case "TypeCast":       return this.genTypeCast(node);
            case "MemberAccess":   return this.genMemberAccess(node);
            case "FunctionCall":   return this.genFunctionCall(node);
            case "IndexAccess":    return this.genIndexAccess(node);
            case "Index2DAccess":  return this.genIndex2DAccess(node);
            case "ArrayLiteral":   return this.genArrayLiteral(node);
            case "TupleLiteral":   return this.genTupleLiteral(node);
            case "TupleAccess":    return this.genTupleAccess(node);
            case "AllocArray":     return this.genAllocArray(node);
            case "RowSlice":       return this.genRowSlice(node);
            case "ColSlice":       return this.genColSlice(node);
            case "LambdaExpr":     return this.genLambda(node);
            case "AwaitExpr":      return this.genExpr(node.left);
            case "ListComprehension": return this.genListComprehension(node);
            default:
                mocha_error("MochaCodeGenError", "Unknown expression kind: " + node.kind);
                return this.exprResult("%t0", "i32");
        };
    };

    // Helper: pack (reg, type) as "reg|type"
    function exprResult(reg: str, llvm_type: str) -> str {
        return reg + "|" + llvm_type;
    };

    // Helper: unpack reg from result
    function exprReg(result: str) -> str {
        var i: int = 0;
        while (i < result.length) {
            if (result.charAt(i) == "|") {
                return result.substring(0, i - 1);
            };
            i = i + 1;
        };
        return result;
    };

    // Helper: unpack type from result
    function exprType(result: str) -> str {
        var i: int = 0;
        while (i < result.length) {
            if (result.charAt(i) == "|") {
                if (i + 1 <= result.length - 1) {
                    return result.substring(i + 1, result.length - 1);
                };
                return "";
            };
            i = i + 1;
        };
        return "i32";
    };

    // --------------------------------------------------------
    // Literals
    // --------------------------------------------------------

    function genIntLiteral(node: ASTNode) -> str {
        var tmp: str = this.freshTemp();
        if (node.int_val > 2147483647 || node.int_val < -2147483648) {
            this.emit("  " + tmp + " = add i64 0, " + str(node.int_val));
            return this.exprResult(tmp, "i64");
        };
        this.emit("  " + tmp + " = add i32 0, " + str(node.int_val));
        return this.exprResult(tmp, "i32");
    };

    function genFloatLiteral(node: ASTNode) -> str {
        var tmp: str = this.freshTemp();
        var val: str = str(node.real_val);
        // ensure decimal point present
        if (val.contains(".") == false && val.contains("e") == false) {
            val = val + ".0";
        };
        this.emit("  " + tmp + " = fadd double 0.0, " + val);
        return this.exprResult(tmp, "double");
    };

    function genBoolLiteral(node: ASTNode) -> str {
        var tmp: str = this.freshTemp();
        var v: int = 0;
        if (node.bool_val) { v = 1; };
        this.emit("  " + tmp + " = add i8 0, " + str(v));
        return this.exprResult(tmp, "i8");
    };

    function genStrLiteral(node: ASTNode) -> str {
        var gname: str = this.freshStrGlobal(node.value);
        var len:   int = node.value.length + 1;
        var tptr:  str = this.freshTemp();
        var tstr:  str = this.freshTemp();
        this.emit("  " + tptr + " = getelementptr [" + str(len) + " x i8], [" + str(len) + " x i8]* " + gname + ", i32 0, i32 0");
        this.emit("  " + tstr + " = call i8* @mocha_str_literal(i8* " + tptr + ")");
        return this.exprResult(tstr, "i8*");
    };

    function genNullLiteral(node: ASTNode) -> str {
        var tmp: str = this.freshTemp();
        this.emit("  " + tmp + " = add i32 0, 0");
        return this.exprResult(tmp, "i32");
    };

    // --------------------------------------------------------
    // Identifier
    // --------------------------------------------------------

    function genIdentifier(node: ASTNode) -> str {
        var tmp: str = this.freshTemp();

        // locals first
        if (this.hasLocal(node.value)) {
            var ptr:      str = this.getLocalPtr(node.value);
            var llvm_type: str = this.getLocalType(node.value);
            this.emit("  " + tmp + " = load " + llvm_type + ", " + llvm_type + "* " + ptr);
            return this.exprResult(tmp, llvm_type);
        };

        // globals
        if (this.global_ptrs.has(node.value)) {
            var gptr:  str = this.global_ptrs.get(node.value); this.keep.push(gptr);
            var gtype: str = this.global_mocha_types.get(node.value); this.keep.push(gtype);
            var llvm_t: str = this.toLLVMType(gtype);
            this.emit("  " + tmp + " = load " + llvm_t + ", " + llvm_t + "* " + gptr);
            return this.exprResult(tmp, llvm_t);
        };

        mocha_error("MochaCodeGenError", "Undeclared variable: '" + node.value + "'");
        return this.exprResult(tmp, "i32");
    };

    function genThis(node: ASTNode) -> str {
        var tmp: str = this.freshTemp();
        var ptr: str = this.getLocalPtr("this");
        var cls: str = "%struct." + this.current_class + "*";
        this.emit("  " + tmp + " = load " + cls + ", " + cls + "* " + ptr);
        return this.exprResult(tmp, cls);
    };

    // --------------------------------------------------------
    // Binary op
    // --------------------------------------------------------

    function genBinaryOp(node: ASTNode) -> str {
        var left_result:  str = this.genExpr(node.left);
        var right_result: str = this.genExpr(node.right);
        var left_reg:     str = this.exprReg(left_result);
        var left_type:    str = this.exprType(left_result);
        var right_reg:    str = this.exprReg(right_result);
        var right_type:   str = this.exprType(right_result);
        var tmp:          str = this.freshTemp();
        var op_kind:      str = node.extra; // op_kind stored in extra by TC

        // Complex ops
        if (op_kind == "complex_add" || op_kind == "complex_sub" ||
            op_kind == "complex_mul" || op_kind == "complex_div") {
            var l: str = this.toComplex(left_reg, left_type);
            var r: str = this.toComplex(right_reg, right_type);
            var cfunc: str = "mocha_complex_add";
            if (op_kind == "complex_sub") { cfunc = "mocha_complex_sub"; };
            if (op_kind == "complex_mul") { cfunc = "mocha_complex_mul"; };
            if (op_kind == "complex_div") { cfunc = "mocha_complex_div"; };
            var ctmp: str = this.freshTemp();
            this.emit("  " + ctmp + " = call %struct.MochaComplex* @" + cfunc + "(%struct.MochaComplex* " + l + ", %struct.MochaComplex* " + r + ")");
            return this.exprResult(ctmp, "%struct.MochaComplex*");
        };

        // Float ops
        if (op_kind == "float_add" || op_kind == "float_sub" ||
            op_kind == "float_mul" || op_kind == "float_div" || op_kind == "float_mod") {
            if (left_type == "i32") {
                var p1: str = this.freshTemp();
                this.emit("  " + p1 + " = sitofp i32 " + left_reg + " to double");
                left_reg  = p1;
                left_type = "double";
            };
            if (right_type == "i32") {
                var p2: str = this.freshTemp();
                this.emit("  " + p2 + " = sitofp i32 " + right_reg + " to double");
                right_reg  = p2;
                right_type = "double";
            };
            var ffunc: str = "mocha_float_add";
            if (op_kind == "float_sub") { ffunc = "mocha_float_sub"; };
            if (op_kind == "float_mul") { ffunc = "mocha_float_mul"; };
            if (op_kind == "float_div") { ffunc = "mocha_float_div"; };
            if (op_kind == "float_mod") { ffunc = "mocha_float_mod"; };
            this.emit("  " + tmp + " = call double @" + ffunc + "(double " + left_reg + ", double " + right_reg + ")");
            return this.exprResult(tmp, "double");
        };

        // Vast ops
        if (op_kind == "vast_add" || op_kind == "vast_sub" ||
            op_kind == "vast_mul" || op_kind == "vast_div" || op_kind == "vast_mod") {
            if (left_type == "i32") {
                var vp1: str = this.freshTemp();
                this.emit("  " + vp1 + " = sext i32 " + left_reg + " to i64");
                left_reg  = vp1;
                left_type = "i64";
            };
            if (right_type == "i32") {
                var vp2: str = this.freshTemp();
                this.emit("  " + vp2 + " = sext i32 " + right_reg + " to i64");
                right_reg  = vp2;
                right_type = "i64";
            };
            var vinstr: str = "add";
            if (op_kind == "vast_sub") { vinstr = "sub"; };
            if (op_kind == "vast_mul") { vinstr = "mul"; };
            if (op_kind == "vast_div") { vinstr = "sdiv"; };
            if (op_kind == "vast_mod") { vinstr = "srem"; };
            this.emit("  " + tmp + " = " + vinstr + " i64 " + left_reg + ", " + right_reg);
            return this.exprResult(tmp, "i64");
        };

        // Int ops
        if (op_kind == "int_add" || op_kind == "int_sub" ||
            op_kind == "int_mul" || op_kind == "int_div" || op_kind == "int_mod") {
            if (left_type == "i64" || right_type == "i64") {
                if (left_type == "i32") {
                    var ip1: str = this.freshTemp();
                    this.emit("  " + ip1 + " = sext i32 " + left_reg + " to i64");
                    left_reg  = ip1;
                    left_type = "i64";
                };
                if (right_type == "i32") {
                    var ip2: str = this.freshTemp();
                    this.emit("  " + ip2 + " = sext i32 " + right_reg + " to i64");
                    right_reg  = ip2;
                    right_type = "i64";
                };
                var i64instr: str = "add";
                if (op_kind == "int_sub") { i64instr = "sub"; };
                if (op_kind == "int_mul") { i64instr = "mul"; };
                if (op_kind == "int_div") { i64instr = "sdiv"; };
                if (op_kind == "int_mod") { i64instr = "srem"; };
                this.emit("  " + tmp + " = " + i64instr + " i64 " + left_reg + ", " + right_reg);
                return this.exprResult(tmp, "i64");
            };
            var iinstr: str = "add";
            if (op_kind == "int_sub") { iinstr = "sub"; };
            if (op_kind == "int_mul") { iinstr = "mul"; };
            if (op_kind == "int_div") { iinstr = "sdiv"; };
            if (op_kind == "int_mod") { iinstr = "srem"; };
            this.emit("  " + tmp + " = " + iinstr + " i32 " + left_reg + ", " + right_reg);
            return this.exprResult(tmp, "i32");
        };

        // String concat
        if (op_kind == "string_concat") {
            this.emit("  " + tmp + " = call i8* @mocha_str_concat(i8* " + left_reg + ", i8* " + right_reg + ")");
            return this.exprResult(tmp, "i8*");
        };

        // String equality
        if (op_kind == "str_eq" || op_kind == "str_ne") {
            var scmp: str = this.freshTemp();
            this.emit("  " + scmp + " = call i32 @mocha_str_eq(i8* " + left_reg + ", i8* " + right_reg + ")");
            var sres: str = this.freshTemp();
            if (op_kind == "str_eq") {
                this.emit("  " + sres + " = icmp ne i32 " + scmp + ", 0");
            } else {
                this.emit("  " + sres + " = icmp eq i32 " + scmp + ", 0");
            };
            var sext: str = this.freshTemp();
            this.emit("  " + sext + " = zext i1 " + sres + " to i8");
            return this.exprResult(sext, "i8");
        };

        // String comparison
        if (op_kind == "str_<" || op_kind == "str_>" ||
            op_kind == "str_<=" || op_kind == "str_>=") {
            var strcmp: str = this.freshTemp();
            this.emit("  " + strcmp + " = call i32 @strcmp(i8* " + left_reg + ", i8* " + right_reg + ")");
            var strres: str = this.freshTemp();
            var strinstr: str = "icmp slt";
            if (op_kind == "str_>")  { strinstr = "icmp sgt"; };
            if (op_kind == "str_<=") { strinstr = "icmp sle"; };
            if (op_kind == "str_>=") { strinstr = "icmp sge"; };
            this.emit("  " + strres + " = " + strinstr + " i32 " + strcmp + ", 0");
            return this.exprResult(strres, "i1");
        };

        // Numeric comparisons
        var cmp_instr: str = "";
        if (op_kind == "int_eq")   { cmp_instr = "icmp eq"; };
        if (op_kind == "int_ne")   { cmp_instr = "icmp ne"; };
        if (op_kind == "int_<")    { cmp_instr = "icmp slt"; };
        if (op_kind == "int_>")    { cmp_instr = "icmp sgt"; };
        if (op_kind == "int_<=")   { cmp_instr = "icmp sle"; };
        if (op_kind == "int_>=")   { cmp_instr = "icmp sge"; };
        if (op_kind == "float_eq") { cmp_instr = "fcmp oeq"; };
        if (op_kind == "float_ne") { cmp_instr = "fcmp one"; };
        if (op_kind == "float_<")  { cmp_instr = "fcmp olt"; };
        if (op_kind == "float_>")  { cmp_instr = "fcmp ogt"; };
        if (op_kind == "float_<=") { cmp_instr = "fcmp ole"; };
        if (op_kind == "float_>=") { cmp_instr = "fcmp oge"; };
        if (op_kind == "vast_eq")  { cmp_instr = "icmp eq"; };
        if (op_kind == "vast_ne")  { cmp_instr = "icmp ne"; };
        if (op_kind == "vast_<")   { cmp_instr = "icmp slt"; };
        if (op_kind == "vast_>")   { cmp_instr = "icmp sgt"; };
        if (op_kind == "vast_<=")  { cmp_instr = "icmp sle"; };
        if (op_kind == "vast_>=")  { cmp_instr = "icmp sge"; };
        if (op_kind == "bool_eq")  { cmp_instr = "icmp eq"; };
        if (op_kind == "bool_ne")  { cmp_instr = "icmp ne"; };

        if (cmp_instr != "") {
            if (op_kind.substring(0, 3) == "floa") {
                if (left_type == "i32") {
                    var fp1: str = this.freshTemp();
                    this.emit("  " + fp1 + " = sitofp i32 " + left_reg + " to double");
                    left_reg = fp1;
                };
                if (right_type == "i32") {
                    var fp2: str = this.freshTemp();
                    this.emit("  " + fp2 + " = sitofp i32 " + right_reg + " to double");
                    right_reg = fp2;
                };
                this.emit("  " + tmp + " = " + cmp_instr + " double " + left_reg + ", " + right_reg);
            } else {
                if (left_type == "i64" && right_type == "i32") {
                    var ep1: str = this.freshTemp();
                    this.emit("  " + ep1 + " = sext i32 " + right_reg + " to i64");
                    right_reg  = ep1;
                    right_type = "i64";
                } else if (left_type == "i32" && right_type == "i64") {
                    var ep2: str = this.freshTemp();
                    this.emit("  " + ep2 + " = sext i32 " + left_reg + " to i64");
                    left_reg  = ep2;
                    left_type = "i64";
                };
                var ltype: str = left_type;
                if (ltype == "i1") { ltype = "i8"; };
                this.emit("  " + tmp + " = " + cmp_instr + " " + ltype + " " + left_reg + ", " + right_reg);
            };
            return this.exprResult(tmp, "i1");
        };

        // Logical ops
        if (op_kind == "bool_and" || op_kind == "bool_or") {
            if (left_type == "i1") {
                var lp: str = this.freshTemp();
                this.emit("  " + lp + " = zext i1 " + left_reg + " to i8");
                left_reg  = lp;
                left_type = "i8";
            };
            if (right_type == "i1") {
                var rp: str = this.freshTemp();
                this.emit("  " + rp + " = zext i1 " + right_reg + " to i8");
                right_reg  = rp;
                right_type = "i8";
            };
            var loginstr: str = "and";
            if (op_kind == "bool_or") { loginstr = "or"; };
            this.emit("  " + tmp + " = " + loginstr + " i8 " + left_reg + ", " + right_reg);
            return this.exprResult(tmp, "i8");
        };

        mocha_error("MochaCodeGenError", "Unknown binary op_kind: " + op_kind);
        return this.exprResult(tmp, "i32");
    };

    function toComplex(reg: str, llvm_type: str) -> str {
        if (llvm_type == "%struct.MochaComplex*") { return reg; };
        if (llvm_type == "i32") {
            var p: str = this.freshTemp();
            this.emit("  " + p + " = sitofp i32 " + reg + " to double");
            reg = p;
        };
        var c: str = this.freshTemp();
        this.emit("  " + c + " = call %struct.MochaComplex* @mocha_complex_new(double " + reg + ", double 0.0)");
        return c;
    };

    // --------------------------------------------------------
    // Unary ops
    // --------------------------------------------------------

    function genUnaryOp(node: ASTNode) -> str {
        var result: str = this.genExpr(node.right);
        var reg:    str = this.exprReg(result);
        var typ:    str = this.exprType(result);
        var tmp:    str = this.freshTemp();

        if (node.value == "!") {
            // bool NOT: xor i8 reg, 1
            this.emit("  " + tmp + " = xor i8 " + reg + ", 1");
            return this.exprResult(tmp, "i8");
        };

        if (node.value == "-") {
            if (typ == "double") {
                this.emit("  " + tmp + " = fneg double " + reg);
                return this.exprResult(tmp, "double");
            };
            if (typ == "i64") {
                this.emit("  " + tmp + " = sub i64 0, " + reg);
                return this.exprResult(tmp, "i64");
            };
            this.emit("  " + tmp + " = sub i32 0, " + reg);
            return this.exprResult(tmp, "i32");
        };

        return this.exprResult(reg, typ);
    };

    function genPreIncrement(node: ASTNode) -> str {
        return this.genIncrDecr(node.right, 1);
    };

    function genPreDecrement(node: ASTNode) -> str {
        return this.genIncrDecr(node.right, -1);
    };

    function genPostIncrement(node: ASTNode) -> str {
        // post: return old value, then increment
        var result: str = this.genExpr(node.left);
        var old_reg: str = this.exprReg(result);
        var typ:     str = this.exprType(result);
        this.genIncrDecr(node.left, 1);
        return this.exprResult(old_reg, typ);
    };

    function genIncrDecr(target: ASTNode, delta: int) -> str {
        var result: str = this.genExpr(target);
        var reg:    str = this.exprReg(result);
        var typ:    str = this.exprType(result);
        var tmp:    str = this.freshTemp();

        if (typ == "i64") {
            this.emit("  " + tmp + " = add i64 " + reg + ", " + str(delta));
        } else {
            this.emit("  " + tmp + " = add i32 " + reg + ", " + str(delta));
        };

        // store back
        if (target.kind == "Identifier") {
            var ptr: str = this.getLocalPtr(target.value);
            this.emit("  store " + typ + " " + tmp + ", " + typ + "* " + ptr);
        };
        return this.exprResult(tmp, typ);
    };

    // --------------------------------------------------------
    // Type cast
    // --------------------------------------------------------

    function genTypeCast(node: ASTNode) -> str {
        var result:    str = this.genExpr(node.left);
        var val_reg:   str = this.exprReg(result);
        var val_type:  str = this.exprType(result);
        var target:    str = this.toLLVMType(node.value);
        var tmp:       str = this.freshTemp();

        if (val_type == "i32" && target == "double") {
            this.emit("  " + tmp + " = sitofp i32 " + val_reg + " to double");
        } else if (val_type == "double" && target == "i32") {
            this.emit("  " + tmp + " = fptosi double " + val_reg + " to i32");
        } else if (val_type == "i32" && target == "i8") {
            this.emit("  " + tmp + " = trunc i32 " + val_reg + " to i8");
        } else if (val_type == "i8" && target == "i32") {
            this.emit("  " + tmp + " = zext i8 " + val_reg + " to i32");
        } else if (val_type == "i8" && target == "double") {
            var mid: str = this.freshTemp();
            this.emit("  " + mid + " = zext i8 " + val_reg + " to i32");
            this.emit("  " + tmp + " = sitofp i32 " + mid + " to double");
        } else if (val_type == "i32" && target == "i64") {
            this.emit("  " + tmp + " = sext i32 " + val_reg + " to i64");
        } else if (val_type == "i64" && target == "i32") {
            this.emit("  " + tmp + " = trunc i64 " + val_reg + " to i32");
        } else if (val_type == "i64" && target == "i8") {
            this.emit("  " + tmp + " = trunc i64 " + val_reg + " to i8");
        } else if (val_type == "i64" && target == "double") {
            this.emit("  " + tmp + " = sitofp i64 " + val_reg + " to double");
        } else if (val_type == "i32" && target == "i8*") {
            this.emit("  " + tmp + " = call i8* @mocha_int_to_str(i32 " + val_reg + ")");
        } else if (val_type == "double" && target == "i8*") {
            this.emit("  " + tmp + " = call i8* @mocha_float_to_str(double " + val_reg + ")");
        } else if (val_type == "i64" && target == "i8*") {
            this.emit("  " + tmp + " = call i8* @mocha_vast_to_str(i64 " + val_reg + ")");
        } else if (val_type == "i8*" && target == "i8*") {
            tmp = val_reg;
        } else {
            this.emit("  " + tmp + " = bitcast " + val_type + " " + val_reg + " to " + target);
        };
        return this.exprResult(tmp, target);
    };

    // --------------------------------------------------------
    // Member access
    // --------------------------------------------------------

    function genMemberAccess(node: ASTNode) -> str {
        var obj_result: str = this.genExpr(node.left);
        var obj_reg:    str = this.exprReg(obj_result);
        var obj_type:   str = this.exprType(obj_result);
        var member:     str = node.value;
        var tmp:        str = this.freshTemp();

        // array length
        if (obj_type == "%MochaArray*") {
            if (member == "length") {
                this.emit("  " + tmp + " = call i32 @mocha_array_length(%MochaArray* " + obj_reg + ")");
                return this.exprResult(tmp, "i32");
            };
        };

        // 2D array rows/cols
        if (obj_type == "%MochaArray2D*") {
            if (member == "rows") {
                this.emit("  " + tmp + " = call i32 @mocha_array2d_rows(%MochaArray2D* " + obj_reg + ")");
                return this.exprResult(tmp, "i32");
            };
            if (member == "cols") {
                this.emit("  " + tmp + " = call i32 @mocha_array2d_cols(%MochaArray2D* " + obj_reg + ")");
                return this.exprResult(tmp, "i32");
            };
        };

        // str length
        if (obj_type == "i8*") {
            if (member == "length") {
                this.emit("  " + tmp + " = call i32 @mocha_str_length(i8* " + obj_reg + ")");
                return this.exprResult(tmp, "i32");
            };
        };

        // struct field access via getelementptr
        var class_name: str = this.inferClassName(obj_type);
        if (class_name != "") {
            var field_idx:  int = this.getFieldIndex(class_name, member);
            var field_type: str = this.getFieldLLVMType(class_name, member);
            if (field_idx >= 0) {
                var struct_type: str = "%struct." + class_name;
                var gep: str = this.freshTemp();
                this.emit("  " + gep + " = getelementptr " + struct_type + ", " + obj_type + " " + obj_reg + ", i32 0, i32 " + str(field_idx));
                this.emit("  " + tmp + " = load " + field_type + ", " + field_type + "* " + gep);
                return this.exprResult(tmp, field_type);
            };
        };

        mocha_error("MochaCodeGenError", "Cannot resolve member '" + member + "' on type '" + obj_type + "'");
        return this.exprResult(tmp, "i32");
    };

    // infer class name from llvm type e.g. "%struct.Dog*" -> "Dog"
    function inferClassName(llvm_type: str) -> str {
        if (llvm_type.length < 9) { return ""; };
        if (llvm_type.substring(0, 6) != "%struct") { return ""; };
        // "%struct.Dog*" -> "Dog"
        var str_start: int = 8; // after "%struct."
        var end:   int = llvm_type.length - 2; // before "*"
        if (end < str_start) { return ""; };
        return llvm_type.substring(str_start, end);
    };

    // --------------------------------------------------------
    // Index access
    // --------------------------------------------------------

    function genIndexAccess(node: ASTNode) -> str {
        var obj_result: str = this.genExpr(node.left);
        var obj_reg:    str = this.exprReg(obj_result);
        var idx_result: str = this.genExpr(node.right);
        var idx_reg:    str = this.exprReg(idx_result);

        // element type from the variable, field, or nested index (default i32, as in Python)
        var elem_llvm: str = "i32";
        var arr_mocha: str = this.inferMochaType(node.left);
        if (arr_mocha != "") {
            elem_llvm = this.toLLVMType(this.extractElemMocha(arr_mocha));
        };

        var slot:   str = this.allocaAtEntry(elem_llvm);
        var cast:   str = this.freshTemp();
        var result: str = this.freshTemp();
        this.emit("  " + cast + " = bitcast " + elem_llvm + "* " + slot + " to i8*");
        this.emit("  call void @mocha_array_get(%MochaArray* " + obj_reg + ", i32 " + idx_reg + ", i8* " + cast + ")");
        this.emit("  " + result + " = load " + elem_llvm + ", " + elem_llvm + "* " + slot);
        return this.exprResult(result, elem_llvm);
    };

    // extract element mocha type from array mocha type
    // remove every "[]" from a type name: int[][] -> int
    function stripArrayBrackets(t: str) -> str {
        var res: str = "";
        var i: int = 0;
        while (i < t.length) {
            var ch: str = t.charAt(i);
            var skip: bool = false;
            if (ch == "[") {
                if (i + 1 < t.length) {
                    if (t.charAt(i + 1) == "]") { skip = true; };
                };
            };
            if (skip) {
                i = i + 2;
            } else {
                res = res + ch;
                i = i + 1;
            };
        };
        return res;
    };

    // Mocha type of an expression: this, variable, field, or index (same rules as the Python codegen)
    function inferMochaType(node: ASTNode) -> str {
        if (node == null) { return ""; };
        if (node.kind == "This") { return this.current_class; };
        if (node.kind == "Identifier") {
            if (node.value == "this") { return this.current_class; };
            if (this.hasLocal(node.value)) { return this.getLocalMochaType(node.value); };
            return "";
        };
        if (node.kind == "MemberAccess") {
            var base_t: str = this.stripArrayBrackets(this.inferMochaType(node.left));
            var ft: str = this.getFieldMochaType(base_t, node.value);
            if (ft == "unknown") { return ""; };
            return ft;
        };
        if (node.kind == "IndexAccess") {
            return this.stripArrayBrackets(this.inferMochaType(node.left));
        };
        return "";
    };

    function getReturnType(name: str, node: ASTNode) -> str {
        if (this.method_return_types.has(name) == false) {
            mocha_error("MochaCodeGenError", "Unknown function or method '" + name + "' - did you forget to import a library?");
            return "void";
        };
        var rt: str = this.method_return_types.get(name); this.keep.push(rt); return rt;
    };
    function extractElemMocha(arr_mocha: str) -> str {
        if (arr_mocha.length < 3) { return "unknown"; };
        var last: str = arr_mocha.charAt(arr_mocha.length - 1);
        if (last != "]") { return arr_mocha; };
        var i: int = arr_mocha.length - 2;
        while (i >= 0) {
            if (arr_mocha.charAt(i) == "[") {
                if (i == 0) { return "unknown"; };
                return arr_mocha.substring(0, i - 1);
            };
            i = i - 1;
        };
        return arr_mocha;
    };

    function llvmTypeSize(llvm_type: str) -> int {
        if (llvm_type == "i1")     { return 1; };
        if (llvm_type == "i8")     { return 1; };
        if (llvm_type == "i32")    { return 4; };
        if (llvm_type == "i64")    { return 8; };
        if (llvm_type == "double") { return 8; };
        if (llvm_type == "i8*")    { return 8; };
        return 8; // pointer default
    };

    // byte size of a class struct the way LLVM lays it out
    function computeStructSize(class_name: str) -> int {
        var offset:    int = 0;
        var max_align: int = 1;
        if (this.class_fields.has(class_name)) {
            var fields: str[] = splitComma(this.class_fields.get(class_name));
            var fi: int = 0;
            while (fi < fields.length) {
                var fsize: int = this.llvmTypeSize(this.fieldType(fields[fi]));
                offset = ((offset + fsize - 1) / fsize) * fsize;
                offset = offset + fsize;
                if (fsize > max_align) { max_align = fsize; };
                fi = fi + 1;
            };
        };
        offset = ((offset + max_align - 1) / max_align) * max_align;
        var size: int = ((offset + 15) / 16) * 16;
        if (size < 16) { size = 16; };
        return size;
    };

    function getZeroValue(lt: str) -> str {
        if (lt == "i32" || lt == "i64" || lt == "i8" || lt == "i16") { return lt + " 0"; };
        if (lt == "double") { return "double 0.0"; };
        if (lt == "i1") { return "i1 0"; };
        return lt + " null";
    };

    // store a zero/null into every field of class_name through the pointer register self_name
    function emitFieldZeroInits(class_name: str, self_name: str) -> null {
        if (this.class_fields.has(class_name) == false) { return; };
        var fields: str[] = splitComma(this.class_fields.get(class_name));
        var zi: int = 0;
        while (zi < fields.length) {
            var zt:  str = this.fieldType(fields[zi]);
            var zn:  str = this.fieldName(fields[zi]);
            var zp:  str = this.freshTemp();
            this.emit("  " + zp + " = getelementptr %struct." + class_name + ", %struct." + class_name + "* " + self_name + ", i32 0, i32 " + str(zi) + "  ; field " + zn);
            this.emit("  store " + this.getZeroValue(zt) + ", " + zt + "* " + zp);
            zi = zi + 1;
        };
    };
    // allocate a zeroed, RC-tracked instance of class_name
    function emitClassAlloc(class_name: str) -> str {
        var size: int = this.computeStructSize(class_name);
        var raw:  str = this.freshTemp();
        var obj:  str = this.freshTemp();
        this.emit("  " + raw + " = call i8* @rc_alloc(i64 " + str(size) + ")  ; sizeof " + class_name);
        this.emit("  call void @llvm.memset.p0i8.i64(i8* " + raw + ", i8 0, i64 " + str(size) + ", i1 false)");
        this.emit("  " + obj + " = bitcast i8* " + raw + " to %struct." + class_name + "*");
        return obj;
    };

    // --------------------------------------------------------
    // Array literal
    // --------------------------------------------------------

    function elemSizeFromExpected(t: str) -> int {
        if (t == "int[]")  { return 4; };
        if (t == "bool[]") { return 1; };
        return 8;
    };

    function genArrayLiteral(node: ASTNode) -> str {
        if (node.children.length == 0) {
            var arr: str = this.freshTemp();
            var esz: int = this.elemSizeFromExpected(this.expected_assign_type);
            this.emit("  " + arr + " = call %MochaArray* @mocha_array_new(i32 0, i32 " + str(esz) + ", i32 0)");
            return this.exprResult(arr, "%MochaArray*");
        };

        var count: int = node.children.length;
        // gen first element to get type
        var first_result: str = this.genExpr(node.children[0]);
        var first_reg:    str = this.exprReg(first_result);
        var first_type:   str = this.exprType(first_result);
        var elem_size:    int = this.llvmTypeSize(first_type);

        var arr: str = this.freshTemp();
        this.emit("  " + arr + " = call %MochaArray* @mocha_array_new(i32 " + str(count) + ", i32 " + str(elem_size) + ", i32 0)");

        // set first element
        this.genArrayInitElem(arr, 0, first_reg, first_type);

        // set remaining elements
        var i: int = 1;
        while (i < node.children.length) {
            var er: str = this.genExpr(node.children[i]);
            this.genArrayInitElem(arr, i, this.exprReg(er), this.exprType(er));
            i = i + 1;
        };

        return this.exprResult(arr, "%MochaArray*");
    };

    function genArrayInitElem(arr: str, index: int, val_reg: str, elem_llvm: str) -> null {
        var cast: str = this.freshTemp();
        if (elem_llvm == "i8*") {
            this.emit("  call void @mocha_array_init_set(%MochaArray* " + arr + ", i32 " + str(index) + ", i8* " + val_reg + ")");
        } else {
            var alloca: str = this.freshTemp();
            this.emit("  " + alloca + " = alloca " + elem_llvm);
            this.emit("  store " + elem_llvm + " " + val_reg + ", " + elem_llvm + "* " + alloca);
            this.emit("  " + cast + " = bitcast " + elem_llvm + "* " + alloca + " to i8*");
            this.emit("  call void @mocha_array_init_set(%MochaArray* " + arr + ", i32 " + str(index) + ", i8* " + cast + ")");
        };
    };

    // --------------------------------------------------------
    // Alloc array
    // --------------------------------------------------------

    function genAllocArray(node: ASTNode) -> str {
        var size_result: str = this.genExpr(node.left);
        var size_reg:    str = this.exprReg(size_result);
        var elem_llvm:   str = this.toLLVMType(node.value);
        var elem_size:   int = this.llvmTypeSize(elem_llvm);
        var tmp:         str = this.freshTemp();

        if (node.right != null) {
            var size2_result: str = this.genExpr(node.right);
            var size2_reg:    str = this.exprReg(size2_result);
            this.emit("  " + tmp + " = call %MochaArray2D* @mocha_array2d_new(i32 " + size_reg + ", i32 " + size2_reg + ", i32 " + str(elem_size) + ", i32 0, i32 " + size2_reg + ")");
            return this.exprResult(tmp, "%MochaArray2D*");
        };

        this.emit("  " + tmp + " = call %MochaArray* @mocha_array_alloc_filled(i32 " + size_reg + ", i32 " + str(elem_size) + ")");
        return this.exprResult(tmp, "%MochaArray*");
    };

    // --------------------------------------------------------
    // Tuple literal
    // --------------------------------------------------------

    function trimSpaces(s: str) -> str {
        var a: int = 0;
        var b: int = s.length - 1;
        while (a <= b && s.charAt(a) == " ") { a = a + 1; };
        while (b >= a && s.charAt(b) == " ") { b = b - 1; };
        if (a > b) { return ""; };
        return s.substring(a, b);
    };

    function isAllDigits(s: str) -> bool {
        if (s.length == 0) { return false; };
        var digits: str = "0123456789";
        var i: int = 0;
        var ok_all: bool = true;
        while (i < s.length) {
            if (digits.contains(s.charAt(i)) == false) { ok_all = false; };
            i = i + 1;
        };
        return ok_all;
    };

    // Mocha type of slot idx of a tuple type like "(int, str, float)" or "(float, 3)"
    function tupleSlotType(mocha_tuple: str, idx: int) -> str {
        if (mocha_tuple.length < 3) { return ""; };
        if (mocha_tuple.charAt(0) != "(") { return ""; };
        var inner: str = mocha_tuple.substring(1, mocha_tuple.length - 2);
        var raw:  str[] = splitComma(inner);
        var toks: str[] = [];
        var i: int = 0;
        while (i < raw.length) {
            toks.push(this.trimSpaces(raw[i]));
            i = i + 1;
        };
        if (toks.length == 0) { return ""; };
        if (toks.length == 1) { return toks[0]; };
        if (toks.length == 2) {
            if (this.isAllDigits(toks[1])) { return toks[0]; };
        };
        if (idx < toks.length) { return toks[idx]; };
        return "";
    };

    function genTupleAccess(node: ASTNode) -> str {
        var tup_result: str = this.genExpr(node.left);
        var tup_reg:    str = this.exprReg(tup_result);
        var tup_mocha:  str = this.inferMochaType(node.left);
        if (tup_mocha == "") {
            if (node.left.kind == "Identifier") {
                if (this.global_mocha_types.has(node.left.value)) {
                    tup_mocha = this.global_mocha_types.get(node.left.value); this.keep.push(tup_mocha);
                };
            };
        };
        var elem_llvm: str = "i32";
        var slot_t: str = this.tupleSlotType(tup_mocha, node.int_val);
        if (slot_t != "") { elem_llvm = this.toLLVMType(slot_t); };

        var raw: str = this.freshTemp();
        this.emit("  " + raw + " = call i8* @mocha_tuple_get(%MochaTuple* " + tup_reg + ", i32 " + str(node.int_val) + ")");
        if (elem_llvm == "i8*") {
            return this.exprResult(raw, "i8*");
        };
        var ptr:    str = this.freshTemp();
        var result: str = this.freshTemp();
        this.emit("  " + ptr + " = bitcast i8* " + raw + " to " + elem_llvm + "*");
        this.emit("  " + result + " = load " + elem_llvm + ", " + elem_llvm + "* " + ptr);
        return this.exprResult(result, elem_llvm);
    };
    function genTupleLiteral(node: ASTNode) -> str {
        var count: int = node.children.length;
        // evaluate every element first: the slot kind depends on the first element's type
        var regs: str[] = [];
        var typs: str[] = [];
        var i: int = 0;
        while (i < count) {
            var er: str = this.genExpr(node.children[i]);
            regs.push(this.exprReg(er));
            typs.push(this.exprType(er));
            i = i + 1;
        };

        var is_ptr: int = 0;
        if (count > 0) {
            if (typs[0] == "i8*") { is_ptr = 1; };
        };
        var wide: bool = false;
        var ex: str = this.expected_assign_type;
        if (ex.length >= 5) {
            if (ex.substring(0, 4) == "(vast") { wide = true; };
        };

        var tup: str = this.freshTemp();
        this.emit("  " + tup + " = call %MochaTuple* @mocha_tuple_new(i32 " + str(count) + ", i32 " + str(is_ptr) + ")");
        i = 0;
        while (i < count) {
            var reg: str = regs[i];
            var typ: str = typs[i];
            if (typ == "i32" && wide) {
                var wreg: str = this.freshTemp();
                this.emit("  " + wreg + " = sext i32 " + reg + " to i64");
                reg = wreg;
                typ = "i64";
            };
            if (typ == "i8*") {
                if (node.children[i].kind == "Identifier") {
                    this.emit("  call void @rc_retain(i8* " + reg + ")");
                };
                this.emit("  call void @mocha_tuple_set(%MochaTuple* " + tup + ", i32 " + str(i) + ", i8* " + reg + ")");
            } else {
                var cast: str = this.boxValue(reg, typ);
                this.emit("  call void @mocha_tuple_set(%MochaTuple* " + tup + ", i32 " + str(i) + ", i8* " + cast + ")");
            };
            i = i + 1;
        };
        return this.exprResult(tup, "%MochaTuple*");
    };

    // --------------------------------------------------------
    // Row/Col slice — placeholder stubs
    // --------------------------------------------------------

    function genRowSlice(node: ASTNode) -> str {
        var obj_result: str = this.genExpr(node.left);
        var obj_reg:    str = this.exprReg(obj_result);
        var idx_result: str = this.genExpr(node.right);
        var idx_reg:    str = this.exprReg(idx_result);
        var tmp:        str = this.freshTemp();
        this.emit("  " + tmp + " = call %MochaArray* @mocha_array2d_get_row(%MochaArray2D* " + obj_reg + ", i32 " + idx_reg + ")");
        return this.exprResult(tmp, "%MochaArray*");
    };

    function genColSlice(node: ASTNode) -> str {
        var obj_result: str = this.genExpr(node.left);
        var obj_reg:    str = this.exprReg(obj_result);
        var idx_result: str = this.genExpr(node.right);
        var idx_reg:    str = this.exprReg(idx_result);
        var tmp:        str = this.freshTemp();
        this.emit("  " + tmp + " = call %MochaArray* @mocha_array2d_get_col(%MochaArray2D* " + obj_reg + ", i32 " + idx_reg + ")");
        return this.exprResult(tmp, "%MochaArray*");
    };

    // --------------------------------------------------------
    // Lambda — stub (deferred)
    // --------------------------------------------------------

    function genLambda(node: ASTNode) -> str {
        // full lambda codegen deferred — return null ptr for now
        var tmp: str = this.freshTemp();
        this.emit("  " + tmp + " = add i32 0, 0");
        return this.exprResult(tmp, "i8*");
    };

    // --------------------------------------------------------
    // List comprehension — stub (deferred)
    // --------------------------------------------------------

    function genListComprehension(node: ASTNode) -> str {
        var tmp: str = this.freshTemp();
        this.emit("  " + tmp + " = call %MochaArray* @mocha_array_new(i32 0, i32 8, i32 0)");
        return this.exprResult(tmp, "%MochaArray*");
    };

    // --------------------------------------------------------
    // Index 2D access — stub
    // --------------------------------------------------------

    function isBorrowedKind(kind: str) -> bool {
        if (kind == "Identifier") { return true; };
        if (kind == "MemberAccess") { return true; };
        if (kind == "Index2DAccess") { return true; };
        return false;
    };

    function genIndex2DAccess(node: ASTNode) -> str {
        var obj_result: str = this.genExpr(node.left);
        var obj_reg:    str = this.exprReg(obj_result);
        var obj_llvm:   str = this.exprType(obj_result);
        var row_result: str = this.genExpr(node.condition);
        var row_reg:    str = this.exprReg(row_result);
        var col_result: str = this.genExpr(node.right);
        var col_reg:    str = this.exprReg(col_result);

        var obj_mocha: str = "";
        if (node.left.kind == "Identifier") {
            if (this.hasLocal(node.left.value)) {
                obj_mocha = this.getLocalMochaType(node.left.value);
            };
        };

        // chained dict access: d["a"]["b"]
        if (obj_llvm == "%MochaDict*" || obj_mocha == "dict") {
            var d_inner: str = this.freshTemp();
            this.emit("  " + d_inner + " = call i8* @mocha_dict_get(%MochaDict* " + obj_reg + ", i8* " + row_reg + ")");
            if (this.isBorrowedKind(node.condition.kind) == false) {
                this.emit("  call void @rc_release(i8* " + row_reg + ")");
            };
            var d_cast: str = this.freshTemp();
            this.emit("  " + d_cast + " = bitcast i8* " + d_inner + " to %MochaDict*");

            var expected: str = this.expected_assign_type;
            var tag_int: int = -1;
            if (expected == "int")   { tag_int = 0; };
            if (expected == "float") { tag_int = 1; };
            if (expected == "str")   { tag_int = 2; };
            if (expected == "bool")  { tag_int = 3; };
            if (expected == "dict")  { tag_int = 4; };
            if (expected == "vast")  { tag_int = 6; };

            var d_val: str = this.freshTemp();
            if (tag_int == -1) {
                this.emit("  " + d_val + " = call i8* @mocha_dict_get(%MochaDict* " + d_cast + ", i8* " + col_reg + ")");
            } else {
                this.emit("  " + d_val + " = call i8* @mocha_dict_get_typed(%MochaDict* " + d_cast + ", i8* " + col_reg + ", i32 " + str(tag_int) + ")");
            };
            if (this.isBorrowedKind(node.right.kind) == false) {
                this.emit("  call void @rc_release(i8* " + col_reg + ")");
            };

            var d_ptr: str = "";
            var d_out: str = "";
            if (expected == "int") {
                d_ptr = this.freshTemp();
                d_out = this.freshTemp();
                this.emit("  " + d_ptr + " = bitcast i8* " + d_val + " to i32*");
                this.emit("  " + d_out + " = load i32, i32* " + d_ptr);
                return this.exprResult(d_out, "i32");
            };
            if (expected == "float") {
                d_ptr = this.freshTemp();
                d_out = this.freshTemp();
                this.emit("  " + d_ptr + " = bitcast i8* " + d_val + " to double*");
                this.emit("  " + d_out + " = load double, double* " + d_ptr);
                return this.exprResult(d_out, "double");
            };
            if (expected == "bool") {
                d_out = this.freshTemp();
                this.emit("  " + d_out + " = load i8, i8* " + d_val);
                return this.exprResult(d_out, "i8");
            };
            if (expected == "vast") {
                d_ptr = this.freshTemp();
                d_out = this.freshTemp();
                this.emit("  " + d_ptr + " = bitcast i8* " + d_val + " to i64*");
                this.emit("  " + d_out + " = load i64, i64* " + d_ptr);
                return this.exprResult(d_out, "i64");
            };
            if (expected == "str") {
                this.emit("  call void @rc_retain(i8* " + d_val + ")");
                return this.exprResult(d_val, "i8*");
            };
            return this.exprResult(d_val, "i8*");
        };

        // 2D array read: element type from the variable or the field (T[][] -> T)
        var elem_llvm: str = "i32";
        var arr_mocha: str = this.assignTargetType(node.left);
        if (arr_mocha != "" && arr_mocha != "unknown") {
            var elem_mocha: str = this.extractElemMocha(this.extractElemMocha(arr_mocha));
            elem_llvm = this.toLLVMType(elem_mocha);
        };
        var slot:   str = this.allocaAtEntry(elem_llvm);
        var cast:   str = this.freshTemp();
        var result: str = this.freshTemp();
        this.emit("  " + cast + " = bitcast " + elem_llvm + "* " + slot + " to i8*");
        this.emit("  call void @mocha_array2d_get(%MochaArray2D* " + obj_reg + ", i32 " + row_reg + ", i32 " + col_reg + ", i8* " + cast + ")");
        this.emit("  " + result + " = load " + elem_llvm + ", " + elem_llvm + "* " + slot);
        return this.exprResult(result, elem_llvm);
    };

    // --------------------------------------------------------
    // Function call — dispatch to codegen_calls.mch
    // --------------------------------------------------------

    function genFunctionCall(node: ASTNode) -> str {
        // This will be fully implemented in codegen_calls.mch
        // For now dispatch based on callee kind
        if (node.left.kind == "MemberAccess") {
            return this.genMemberCall(node);
        };
        if (node.left.kind == "Identifier") {
            return this.genDirectCall(node);
        };
        var tmp: str = this.freshTemp();
        this.emit("  " + tmp + " = add i32 0, 0");
        return this.exprResult(tmp, "i32");
    };
};