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
            case "DictLiteral":    return this.genDictLiteral(node);
            case "SetLiteral":     return this.genSetLiteral(node);
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

    function genDictRead(node: ASTNode, d_reg: str, key_reg: str) -> str {
        var dr_expected: str = this.expected_assign_type;
        var dr_tag: int = -1;
        if (dr_expected == "int")   { dr_tag = 0; };
        if (dr_expected == "float") { dr_tag = 1; };
        if (dr_expected == "str")   { dr_tag = 2; };
        if (dr_expected == "bool")  { dr_tag = 3; };
        if (dr_expected == "dict")  { dr_tag = 4; };
        if (dr_expected == "vast")  { dr_tag = 6; };
        var dr_raw: str = this.freshTemp();
        if (dr_tag == -1) {
            this.emit("  " + dr_raw + " = call i8* @mocha_dict_get(%MochaDict* " + d_reg + ", i8* " + key_reg + ")");
        } else {
            this.emit("  " + dr_raw + " = call i8* @mocha_dict_get_typed(%MochaDict* " + d_reg + ", i8* " + key_reg + ", i32 " + str(dr_tag) + ")");
        };
        if (this.isBorrowedKind(node.right.kind) == false) {
            this.emit("  call void @rc_release(i8* " + key_reg + ")");
        };
        var dr_ptr: str = "";
        var dr_val: str = "";
        if (dr_expected == "int") {
            dr_ptr = this.freshTemp();
            dr_val = this.freshTemp();
            this.emit("  " + dr_ptr + " = bitcast i8* " + dr_raw + " to i32*");
            this.emit("  " + dr_val + " = load i32, i32* " + dr_ptr);
            return this.exprResult(dr_val, "i32");
        };
        if (dr_expected == "float") {
            dr_ptr = this.freshTemp();
            dr_val = this.freshTemp();
            this.emit("  " + dr_ptr + " = bitcast i8* " + dr_raw + " to double*");
            this.emit("  " + dr_val + " = load double, double* " + dr_ptr);
            return this.exprResult(dr_val, "double");
        };
        if (dr_expected == "bool") {
            dr_val = this.freshTemp();
            this.emit("  " + dr_val + " = load i8, i8* " + dr_raw);
            return this.exprResult(dr_val, "i8");
        };
        if (dr_expected == "vast") {
            dr_ptr = this.freshTemp();
            dr_val = this.freshTemp();
            this.emit("  " + dr_ptr + " = bitcast i8* " + dr_raw + " to i64*");
            this.emit("  " + dr_val + " = load i64, i64* " + dr_ptr);
            return this.exprResult(dr_val, "i64");
        };
        if (dr_expected == "str") {
            this.emit("  call void @rc_retain(i8* " + dr_raw + ")");
            return this.exprResult(dr_raw, "i8*");
        };
        return this.exprResult(dr_raw, "i8*");
    };

    function genIndexAccess(node: ASTNode) -> str {
        var obj_result: str = this.genExpr(node.left);
        var obj_reg:    str = this.exprReg(obj_result);
        var idx_result: str = this.genExpr(node.right);
        var idx_reg:    str = this.exprReg(idx_result);
        if (this.exprType(obj_result) == "%MochaDict*") { return this.genDictRead(node, obj_reg, idx_reg); };

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

    function lamHasName(list: str[], nm: str) -> bool {
        var li: int = 0;
        while (li < list.length) {
            if (list[li] == nm) { return true; };
            li = li + 1;
        };
        return false;
    };

    function collectCapturedList(items: ASTNode[]) -> null {
        var ci2: int = 0;
        while (ci2 < items.length) {
            this.collectCaptured(items[ci2]);
            ci2 = ci2 + 1;
        };
    };

    function collectCaptured(n: ASTNode) -> null {
        if (n != null) {
            if (n.kind == "Identifier") {
                var idn: str = n.value;
                if (this.hasLocal(idn)) {
                    if (this.lamHasName(this.cap_params, idn) == false) {
                        if (this.lamHasName(this.cap_names, idn) == false) {
                            this.cap_names.push(idn);
                        };
                    };
                };
            };
            this.collectCaptured(n.left);
            this.collectCaptured(n.right);
            this.collectCaptured(n.condition);
            this.collectCapturedList(n.body);
            this.collectCapturedList(n.children);
            this.collectCapturedList(n.params);
            this.collectCapturedList(n.args);
            this.collectCapturedList(n.else_body);
            this.collectCapturedList(n.else_ifs);
            this.collectCapturedList(n.cases);
        };
    };

    function emitBundle(fn_cast: str, env_reg: str, ret_tag: int) -> str {
        var bundle:  str = this.freshTemp();
        var slot0:   str = this.freshTemp();
        var slot1:   str = this.freshTemp();
        var slot2:   str = this.freshTemp();
        var tag_ptr: str = this.freshTemp();
        this.emit("  " + bundle + " = call i8* @malloc(i64 24)");
        this.emit("  " + slot0 + " = bitcast i8* " + bundle + " to i8**");
        this.emit("  store i8* " + fn_cast + ", i8** " + slot0);
        this.emit("  " + slot1 + " = getelementptr i8*, i8** " + slot0 + ", i32 1");
        this.emit("  store i8* " + env_reg + ", i8** " + slot1);
        this.emit("  " + slot2 + " = getelementptr i8*, i8** " + slot0 + ", i32 2");
        this.emit("  " + tag_ptr + " = bitcast i8** " + slot2 + " to i32*");
        this.emit("  store i32 " + str(ret_tag) + ", i32* " + tag_ptr);
        return bundle;
    };

    function genLambda(node: ASTNode) -> str {
        var lname: str = "mocha_lambda_" + str(this.temp_count);
        this.temp_count = this.temp_count + 1;

        // 1. captured variables
        this.cap_params = [];
        this.cap_names = [];
        var pi1: int = 0;
        while (pi1 < node.params.length) {
            this.cap_params.push(node.params[pi1].value);
            pi1 = pi1 + 1;
        };
        this.collectCaptured(node.left);
        var ncap: int = this.cap_names.length;
        var has_cap: bool = ncap > 0;

        var cptrs:   str[] = [];
        var ctypes:  str[] = [];
        var cmochas: str[] = [];
        var cn_i: int = 0;
        while (cn_i < ncap) {
            var cn: str = this.cap_names[cn_i];
            var c_ptr: str = this.getLocalPtr(cn);   this.keep.push(c_ptr);
            var c_ty:  str = this.getLocalType(cn);  this.keep.push(c_ty);
            var c_mt:  str = this.getLocalMochaType(cn); this.keep.push(c_mt);
            cptrs.push(c_ptr);
            ctypes.push(c_ty);
            cmochas.push(c_mt);
            cn_i = cn_i + 1;
        };

        // 2. env struct + allocation (in the OUTER function)
        var env_type: str = "%env_" + lname;
        var env_reg:  str = "null";
        var env_cast: str = "";
        if (has_cap) {
            var ftypes: str = "";
            var ft_i: int = 0;
            while (ft_i < ncap) {
                if (ft_i > 0) { ftypes = ftypes + ", "; };
                ftypes = ftypes + ctypes[ft_i];
                ft_i = ft_i + 1;
            };
            this.type_declarations.push(env_type + " = type { " + ftypes + " }");
            var env_alloc: str = this.freshTemp();
            env_cast = this.freshTemp();
            this.emit("  " + env_alloc + " = call i8* @malloc(i64 " + str(ncap * 8) + ")");
            this.emit("  " + env_cast + " = bitcast i8* " + env_alloc + " to " + env_type + "*");
            var ev_i: int = 0;
            while (ev_i < ncap) {
                var ev_val: str = this.freshTemp();
                var ev_fp:  str = this.freshTemp();
                this.emit("  " + ev_val + " = load " + ctypes[ev_i] + ", " + ctypes[ev_i] + "* " + cptrs[ev_i]);
                this.emit("  " + ev_fp + " = getelementptr " + env_type + ", " + env_type + "* " + env_cast + ", i32 0, i32 " + str(ev_i));
                this.emit("  store " + ctypes[ev_i] + " " + ev_val + ", " + ctypes[ev_i] + "* " + ev_fp);
                ev_i = ev_i + 1;
            };
            env_reg = env_cast;
        };

        // 3. lambda function text
        var ret_llvm: str = "i8";
        if (node.type_str != "") { ret_llvm = this.toLLVMType(node.type_str); };
        var param_str: str = "";
        var sig_str:   str = "";
        var ps_i: int = 0;
        while (ps_i < node.params.length) {
            param_str = param_str + "i8* %" + node.params[ps_i].value + "_raw, ";
            sig_str = sig_str + "i8*, ";
            ps_i = ps_i + 1;
        };
        if (has_cap) {
            param_str = param_str + env_type + "* %env";
            sig_str = sig_str + env_type + "*";
        } else {
            param_str = param_str + "i8* %env_unused";
            sig_str = sig_str + "i8*";
        };

        var out_start: int = this.output.length;
        var al_start:  int = this.entry_allocas.length;
        this.emit("define " + ret_llvm + " @" + lname + "(" + param_str + ") {");
        this.emit("entry:");

        // remember outer locals that the lambda shadows
        var sv_names:  str[] = [];
        var sv_ptrs:   str[] = [];
        var sv_types:  str[] = [];
        var sv_mochas: str[] = [];
        var sh_i: int = 0;
        while (sh_i < this.cap_params.length) {
            var sh_n: str = this.cap_params[sh_i];
            if (this.hasLocal(sh_n)) {
                var sh_p: str = this.getLocalPtr(sh_n);        this.keep.push(sh_p);
                var sh_t: str = this.getLocalType(sh_n);       this.keep.push(sh_t);
                var sh_m: str = this.getLocalMochaType(sh_n);  this.keep.push(sh_m);
                sv_names.push(sh_n); sv_ptrs.push(sh_p); sv_types.push(sh_t); sv_mochas.push(sh_m);
            };
            sh_i = sh_i + 1;
        };
        var sc_i: int = 0;
        while (sc_i < ncap) {
            sv_names.push(this.cap_names[sc_i]); sv_ptrs.push(cptrs[sc_i]);
            sv_types.push(ctypes[sc_i]); sv_mochas.push(cmochas[sc_i]);
            sc_i = sc_i + 1;
        };

        // params: unpack from i8* into a local slot
        var pl_i: int = 0;
        while (pl_i < node.params.length) {
            var pnode: ASTNode = node.params[pl_i];
            var p_llvm: str = this.toLLVMType(pnode.type_str);
            var p_cast: str = this.freshTemp();
            var p_val:  str = this.freshTemp();
            var p_slot: str = "%" + pnode.value + ".ptr";
            this.emit("  " + p_cast + " = bitcast i8* %" + pnode.value + "_raw to " + p_llvm + "*");
            this.emit("  " + p_val + " = load " + p_llvm + ", " + p_llvm + "* " + p_cast);
            this.emit("  " + p_slot + " = alloca " + p_llvm);
            this.emit("  store " + p_llvm + " " + p_val + ", " + p_llvm + "* " + p_slot);
            this.declareLocal(pnode.value, p_slot, p_llvm, pnode.type_str);
            pl_i = pl_i + 1;
        };

        // captured: load from %env into a local slot
        var cl_i: int = 0;
        while (cl_i < ncap) {
            var cl_name: str = this.cap_names[cl_i];
            var cl_fp:   str = this.freshTemp();
            var cl_val:  str = this.freshTemp();
            var cl_slot: str = "%captured_" + cl_name + ".ptr";
            this.emit("  " + cl_fp + " = getelementptr " + env_type + ", " + env_type + "* %env, i32 0, i32 " + str(cl_i));
            this.emit("  " + cl_val + " = load " + ctypes[cl_i] + ", " + ctypes[cl_i] + "* " + cl_fp);
            this.emit("  " + cl_slot + " = alloca " + ctypes[cl_i]);
            this.emit("  store " + ctypes[cl_i] + " " + cl_val + ", " + ctypes[cl_i] + "* " + cl_slot);
            this.declareLocal(cl_name, cl_slot, ctypes[cl_i], cmochas[cl_i]);
            cl_i = cl_i + 1;
        };

        // body
        var body_res: str = this.genExpr(node.left);
        var body_reg: str = this.exprReg(body_res);
        var body_ty:  str = this.exprType(body_res);
        var fin_reg:  str = this.coerceToType(body_reg, body_ty, ret_llvm);
        this.emit("  ret " + ret_llvm + " " + fin_reg);
        this.emit("}");
        this.emitBlank();

        // cut the lambda out of output into type_declarations; allocas go right after "entry:"
        var lam_lines: str[] = [];
        lam_lines.push(this.output[out_start]);
        lam_lines.push(this.output[out_start + 1]);
        var la_i: int = al_start;
        while (la_i < this.entry_allocas.length) {
            lam_lines.push(this.entry_allocas[la_i]);
            la_i = la_i + 1;
        };
        var lb_i: int = out_start + 2;
        while (lb_i < this.output.length) {
            lam_lines.push(this.output[lb_i]);
            lb_i = lb_i + 1;
        };
        var out_keep: str[] = [];
        var ok_i: int = 0;
        while (ok_i < out_start) {
            out_keep.push(this.output[ok_i]);
            ok_i = ok_i + 1;
        };
        this.output = out_keep;
        var al_keep: str[] = [];
        var ak_i: int = 0;
        while (ak_i < al_start) {
            al_keep.push(this.entry_allocas[ak_i]);
            ak_i = ak_i + 1;
        };
        this.entry_allocas = al_keep;
        var lt_i: int = 0;
        while (lt_i < lam_lines.length) {
            this.type_declarations.push(lam_lines[lt_i]);
            lt_i = lt_i + 1;
        };

        // put the shadowed outer locals back
        var rs_i: int = 0;
        while (rs_i < sv_names.length) {
            this.declareLocal(sv_names[rs_i], sv_ptrs[rs_i], sv_types[rs_i], sv_mochas[rs_i]);
            rs_i = rs_i + 1;
        };

        // 4. closure bundle
        var ret_tag: int = 0;
        if (ret_llvm == "double") { ret_tag = 1; };
        if (ret_llvm == "i8*")    { ret_tag = 2; };
        var fn_cast: str = this.freshTemp();
        this.emit("  " + fn_cast + " = bitcast " + ret_llvm + " (" + sig_str + ")* @" + lname + " to i8*");
        var env_i8: str = "null";
        if (has_cap) {
            env_i8 = this.freshTemp();
            this.emit("  " + env_i8 + " = bitcast " + env_type + "* " + env_cast + " to i8*");
        };
        var bundle_reg: str = this.emitBundle(fn_cast, env_i8, ret_tag);
        return this.exprResult(bundle_reg, "i8*");
    };

    // --------------------------------------------------------
    // List comprehension — stub (deferred)
    // --------------------------------------------------------

    function dictArraySetter(t: str) -> str {
        var dl: int = t.length;
        if (dl < 3) { return ""; };
        if (t.charAt(dl - 1) != "]") { return ""; };
        if (t.charAt(dl - 2) != "[") { return ""; };
        var dbase: str = t.substring(0, dl - 3);
        if (dbase == "int")   { return "mocha_dict_set_arr_int"; };
        if (dbase == "float") { return "mocha_dict_set_arr_float"; };
        if (dbase == "str")   { return "mocha_dict_set_arr_str"; };
        if (dbase == "bool")  { return "mocha_dict_set_arr_bool"; };
        if (dbase == "vast")  { return "mocha_dict_set_arr_vast"; };
        return "";
    };

    function genDictLiteral(node: ASTNode) -> str {
        var dd: str = this.freshTemp();
        this.emit("  " + dd + " = call %MochaDict* @mocha_dict_new()");
        var di: int = 0;
        while (di + 1 < node.children.length) {
            var dkn: ASTNode = node.children[di];
            var dvn: ASTNode = node.children[di + 1];
            var dkr: str = this.exprReg(this.genExpr(dkn));
            var dvres: str = this.genExpr(dvn);
            var dvr: str = this.exprReg(dvres);
            var dvt: str = this.exprType(dvres);
            if (dvt == "i1") { dvr = this.coerceToType(dvr, "i1", "i8"); dvt = "i8"; };
            if (dvt == "i32") {
                this.emit("  call void @mocha_dict_set_int(%MochaDict* " + dd + ", i8* " + dkr + ", i32 " + dvr + ")");
            } else if (dvt == "double") {
                this.emit("  call void @mocha_dict_set_float(%MochaDict* " + dd + ", i8* " + dkr + ", double " + dvr + ")");
            } else if (dvt == "i8") {
                this.emit("  call void @mocha_dict_set_bool(%MochaDict* " + dd + ", i8* " + dkr + ", i8 " + dvr + ")");
            } else if (dvt == "i64") {
                this.emit("  call void @mocha_dict_set_vast(%MochaDict* " + dd + ", i8* " + dkr + ", i64 " + dvr + ")");
            } else if (dvt == "%MochaDict*") {
                if (this.isBorrowedKind(dvn.kind)) {
                    this.emit("  call void @mocha_dict_retain(%MochaDict* " + dvr + ")");
                };
                this.emit("  call void @mocha_dict_set_dict(%MochaDict* " + dd + ", i8* " + dkr + ", %MochaDict* " + dvr + ")");
            } else if (dvt.contains("%struct.")) {
                var dcast: str = this.freshTemp();
                this.emit("  " + dcast + " = bitcast " + dvt + " " + dvr + " to i8*");
                this.emit("  call void @mocha_dict_set_object(%MochaDict* " + dd + ", i8* " + dkr + ", i8* " + dcast + ")");
            } else if (dvt == "%MochaArray*") {
                var damt: str = this.inferMochaType(dvn);
                this.keep.push(damt);
                var dsetter: str = this.dictArraySetter(damt);
                if (dsetter == "") {
                    mocha_error("MochaCodeGenError", "Cannot store this array in a dict: its element type is unknown or unsupported (got '" + damt + "'). Supported: int[], float[], str[], bool[], vast[].");
                } else {
                    this.emit("  call void @" + dsetter + "(%MochaDict* " + dd + ", i8* " + dkr + ", %MochaArray* " + dvr + ")");
                };
            } else {
                this.emit("  call void @mocha_dict_set_str(%MochaDict* " + dd + ", i8* " + dkr + ", i8* " + dvr + ")");
            };
            di = di + 2;
        };
        return this.exprResult(dd, "%MochaDict*");
    };

    function genDictMethodCall(d_reg: str, member: str, node: ASTNode) -> str {
        var dmt: str = this.freshTemp();
        if (member == "has") {
            var hargs: str[] = this.collectArgs(node);
            this.emit("  " + dmt + " = call i8 @mocha_dict_has(%MochaDict* " + d_reg + ", i8* " + this.exprReg(hargs[0]) + ")");
            return this.exprResult(dmt, "i8");
        };
        if (member == "remove") {
            var rargs: str[] = this.collectArgs(node);
            this.emit("  call void @mocha_dict_remove(%MochaDict* " + d_reg + ", i8* " + this.exprReg(rargs[0]) + ")");
            return this.exprResult("void", "void");
        };
        if (member == "clean") {
            this.emit("  call void @mocha_dict_clean(%MochaDict* " + d_reg + ")");
            return this.exprResult("void", "void");
        };
        if (member == "allKeys") {
            this.emit("  " + dmt + " = call %MochaArray* @mocha_dict_allkeys(%MochaDict* " + d_reg + ")");
            return this.exprResult(dmt, "%MochaArray*");
        };
        if (member == "allValues") {
            this.emit("  " + dmt + " = call %MochaArray* @mocha_dict_allvalues(%MochaDict* " + d_reg + ")");
            return this.exprResult(dmt, "%MochaArray*");
        };
        if (member == "jsonify") {
            this.emit("  " + dmt + " = call i8* @mocha_dict_jsonify(%MochaDict* " + d_reg + ")");
            return this.exprResult(dmt, "i8*");
        };
        if (member == "merge") {
            var movr: int = 0;
            var mnamed: ASTNode = this.findNamedArg(node, "override");
            if (mnamed != null) {
                if (mnamed.kind == "BoolLiteral") {
                    if (mnamed.bool_val) { movr = 1; };
                };
            };
            var margs: str[] = this.collectArgs(node);
            this.emit("  " + dmt + " = call %MochaDict* @mocha_dict_merge(%MochaDict* " + d_reg + ", %MochaDict* " + this.exprReg(margs[0]) + ", i8 " + str(movr) + ")");
            return this.exprResult(dmt, "%MochaDict*");
        };
        if (member == "copy") {
            this.emit("  " + dmt + " = call %MochaDict* @mocha_dict_copy(%MochaDict* " + d_reg + ")");
            return this.exprResult(dmt, "%MochaDict*");
        };
        mocha_error("MochaCodeGenError", "Unknown dict method '" + member + "'");
        return this.exprResult("void", "void");
    };

    function setTypeTag(llvm: str) -> int {
        if (llvm.contains("%struct.")) { return 5; };
        if (llvm == "double") { return 1; };
        if (llvm == "i8*")    { return 2; };
        if (llvm == "i8")     { return 3; };
        if (llvm == "i64")    { return 4; };
        return 0;
    };

    function emitSetInsert(s_reg: str, val_reg: str, val_llvm: str) -> null {
        var sslot: str = this.allocaAtEntry(val_llvm);
        this.emit("  store " + val_llvm + " " + val_reg + ", " + val_llvm + "* " + sslot);
        var scast: str = this.freshTemp();
        this.emit("  " + scast + " = bitcast " + val_llvm + "* " + sslot + " to i8*");
        this.emit("  call void @mocha_set_insert(%MochaSet* " + s_reg + ", i8* " + scast + ")");
    };

    function genSetLiteral(node: ASTNode) -> str {
        var stag: int = 0;
        var first_res: str = "";
        var first_reg: str = "";
        var first_llvm: str = "i32";
        if (node.children.length > 0) {
            first_res = this.genExpr(node.children[0]);
            first_reg = this.exprReg(first_res);
            first_llvm = this.exprType(first_res);
            if (first_llvm == "i1") { first_reg = this.coerceToType(first_reg, "i1", "i8"); first_llvm = "i8"; };
            stag = this.setTypeTag(first_llvm);
        };
        var ss: str = this.freshTemp();
        this.emit("  " + ss + " = call %MochaSet* @mocha_set_new(i32 " + str(stag) + ")");
        if (node.children.length > 0) {
            this.emitSetInsert(ss, first_reg, first_llvm);
        };
        var sli: int = 1;
        while (sli < node.children.length) {
            var sres: str = this.genExpr(node.children[sli]);
            var sreg: str = this.exprReg(sres);
            var sllvm: str = this.exprType(sres);
            if (sllvm == "i1") { sreg = this.coerceToType(sreg, "i1", "i8"); sllvm = "i8"; };
            this.emitSetInsert(ss, sreg, sllvm);
            sli = sli + 1;
        };
        return this.exprResult(ss, "%MochaSet*");
    };

    function genSetMethodCall(s_reg: str, member: str, node: ASTNode, obj_name: str) -> str {
        var smt: str = this.freshTemp();
        if (member == "insert") {
            var iargs: str[] = this.collectArgs(node);
            var ireg: str = this.exprReg(iargs[0]);
            var itype: str = this.exprType(iargs[0]);
            if (itype == "i1") { ireg = this.coerceToType(ireg, "i1", "i8"); itype = "i8"; };
            this.emitSetInsert(s_reg, ireg, itype);
            return this.exprResult("void", "void");
        };
        if (member == "delete") {
            var dargs: str[] = this.collectArgs(node);
            var dreg: str = this.exprReg(dargs[0]);
            var dtype: str = this.exprType(dargs[0]);
            if (dtype == "i1") { dreg = this.coerceToType(dreg, "i1", "i8"); dtype = "i8"; };
            var dbox: str = this.boxTemp(dreg, dtype);
            this.emit("  call void @mocha_set_delete(%MochaSet* " + s_reg + ", i8* " + dbox + ")");
            return this.exprResult("void", "void");
        };
        if (member == "has") {
            var hargs2: str[] = this.collectArgs(node);
            var hreg: str = this.exprReg(hargs2[0]);
            var htype: str = this.exprType(hargs2[0]);
            if (htype == "i1") { hreg = this.coerceToType(hreg, "i1", "i8"); htype = "i8"; };
            var hbox: str = this.boxTemp(hreg, htype);
            this.emit("  " + smt + " = call i8 @mocha_set_has(%MochaSet* " + s_reg + ", i8* " + hbox + ")");
            return this.exprResult(smt, "i8");
        };
        if (member == "clean") {
            this.emit("  call void @mocha_set_clean(%MochaSet* " + s_reg + ")");
            return this.exprResult("void", "void");
        };
        if (member == "negate") {
            this.emit("  call void @mocha_set_negate(%MochaSet* " + s_reg + ")");
            return this.exprResult("void", "void");
        };
        if (member == "retype") {
            var rnew: str = "int";
            var rtag: int = 0;
            var rai: int = 0;
            while (rai < node.args.length) {
                if (node.args[rai].kind == "Identifier") { rnew = node.args[rai].value; };
                rai = rai + 1;
            };
            if (rnew == "int")    { rtag = 0; }
            else if (rnew == "float")  { rtag = 1; }
            else if (rnew == "str")    { rtag = 2; }
            else if (rnew == "bool")   { rtag = 3; }
            else if (rnew == "vast")   { rtag = 4; }
            else if (rnew == "object") { rtag = 5; }
            else { mocha_error("MochaCodeGenError", "retype(): unknown type '" + rnew + "'. Valid types: int, float, str, bool, vast, object."); };
            this.emit("  call void @mocha_set_retype(%MochaSet* " + s_reg + ", i32 " + str(rtag) + ")");
            if (obj_name != "") {
                var rnt: str = "set<" + rnew + ">";
                this.keep.push(rnt);
                this.local_mocha_types.put(obj_name, rnt);
            };
            return this.exprResult("void", "void");
        };
        if (member == "union") {
            var uargs: str[] = this.collectArgs(node);
            this.emit("  " + smt + " = call %MochaSet* @mocha_set_union(%MochaSet* " + s_reg + ", %MochaSet* " + this.exprReg(uargs[0]) + ")");
            return this.exprResult(smt, "%MochaSet*");
        };
        if (member == "intersect" || member == "xor" || member == "rel_diff") {
            var sm_a: str[] = this.collectArgs(node);
            this.emit("  " + smt + " = call %MochaSet* @mocha_set_" + member + "(%MochaSet* " + s_reg + ", %MochaSet* " + this.exprReg(sm_a[0]) + ")");
            return this.exprResult(smt, "%MochaSet*");
        };
        if (member == "jaccard" || member == "dice" || member == "overlap") {
            var sd_a: str[] = this.collectArgs(node);
            this.emit("  " + smt + " = call double @mocha_set_" + member + "(%MochaSet* " + s_reg + ", %MochaSet* " + this.exprReg(sd_a[0]) + ")");
            return this.exprResult(smt, "double");
        };
        if (member == "subset") {
            var ss_a: str[] = this.collectArgs(node);
            this.emit("  " + smt + " = call i8 @mocha_set_subset(%MochaSet* " + s_reg + ", %MochaSet* " + this.exprReg(ss_a[0]) + ")");
            return this.exprResult(smt, "i8");
        };
        if (member == "superset") {
            var sp_a: str[] = this.collectArgs(node);
            this.emit("  " + smt + " = call i8 @mocha_set_subset(%MochaSet* " + this.exprReg(sp_a[0]) + ", %MochaSet* " + s_reg + ")");
            return this.exprResult(smt, "i8");
        };
        if (member == "min" || member == "max") {
            var mm_t: str = this.inferMochaType(node.left.left);
            this.keep.push(mm_t);
            if (mm_t == "" && obj_name != "") {
                if (this.global_mocha_types.has(obj_name)) {
                    mm_t = this.global_mocha_types.get(obj_name); this.keep.push(mm_t);
                };
            };
            if (mm_t.contains("set<") == false) {
                mocha_error("MochaCodeGenError", "Cannot determine the element type of this set for " + member + "(). Store the set in a variable declared as set<type> first.");
                return this.exprResult("void", "void");
            };
            var mm_inner: str = mm_t.substring(4, mm_t.length - 2);
            var mm_suffix: str = "";
            var mm_ret: str = "";
            if (mm_inner == "int")   { mm_suffix = "int";   mm_ret = "i32"; };
            if (mm_inner == "float") { mm_suffix = "float"; mm_ret = "double"; };
            if (mm_inner == "vast")  { mm_suffix = "vast";  mm_ret = "i64"; };
            if (mm_inner == "str")   { mm_suffix = "str";   mm_ret = "i8*"; };
            if (mm_suffix == "") {
                mocha_error("MochaCodeGenError", member + "() is not supported on set<" + mm_inner + ">. Supported element types: int, float, vast, str.");
                return this.exprResult("void", "void");
            };
            this.emit("  " + smt + " = call " + mm_ret + " @mocha_set_" + member + "_" + mm_suffix + "(%MochaSet* " + s_reg + ")");
            return this.exprResult(smt, mm_ret);
        };
        mocha_error("MochaCodeGenError", "Set method '" + member + "' is not ported yet");
        return this.exprResult("void", "void");
    };

    function genListComprehension(node: ASTNode) -> str {
        // element types (the parser does not set them, so infer)
        var lc_iter_mt: str = this.inferMochaType(node.right);
        this.keep.push(lc_iter_mt);
        var lc_sb: int = lc_iter_mt.length - 1;
        while (lc_sb >= 0) {
            if (lc_iter_mt.charAt(lc_sb) == "[") { break; };
            lc_sb = lc_sb - 1;
        };
        var lc_src_mt: str = "int";
        if (lc_sb > 0) { lc_src_mt = lc_iter_mt.substring(0, lc_sb - 1); };
        var lc_src_llvm: str = this.toLLVMType(lc_src_mt);

        // iterable (evaluated before the loop variable exists)
        var lc_it: str = this.genExpr(node.right);
        var lc_iter_reg: str = this.exprReg(lc_it);

        // loop variable, shadowing any outer local of the same name
        var lc_had: bool = this.hasLocal(node.value);
        var lc_old_p: str = "";
        var lc_old_t: str = "";
        var lc_old_m: str = "";
        if (lc_had) {
            lc_old_p = this.getLocalPtr(node.value);       this.keep.push(lc_old_p);
            lc_old_t = this.getLocalType(node.value);      this.keep.push(lc_old_t);
            lc_old_m = this.getLocalMochaType(node.value); this.keep.push(lc_old_m);
        };
        var lc_elem_ptr: str = this.allocaAtEntry(lc_src_llvm);
        this.declareLocal(node.value, lc_elem_ptr, lc_src_llvm, lc_src_mt);

        var lc_elem_mt: str = this.inferMochaType(node.left);
        this.keep.push(lc_elem_mt);
        if (lc_elem_mt == "" || lc_elem_mt == "unknown") { lc_elem_mt = lc_src_mt; };
        var lc_elem_llvm: str = this.toLLVMType(lc_elem_mt);
        if (lc_elem_llvm == "i1") { lc_elem_llvm = "i8"; };
        var lc_size: int = 8;
        if (lc_elem_llvm == "i32") { lc_size = 4; };
        if (lc_elem_llvm == "i8")  { lc_size = 1; };

        var lc_has_else: bool = false;
        if (node.condition != null) {
            if (node.else_body.length > 0) { lc_has_else = true; };
        };

        // result array in a stack slot
        var lc_res: str = this.freshTemp();
        this.emit("  " + lc_res + " = call %MochaArray* @mocha_array_new(i32 0, i32 " + str(lc_size) + ", i32 0)");
        var lc_arr_ptr: str = this.allocaAtEntry("%MochaArray*");
        this.emit("  store %MochaArray* " + lc_res + ", %MochaArray** " + lc_arr_ptr);

        var lc_len: str = this.freshTemp();
        this.emit("  " + lc_len + " = call i32 @mocha_array_length(%MochaArray* " + lc_iter_reg + ")");
        var lc_idx_ptr: str = this.allocaAtEntry("i32");
        this.emit("  store i32 0, i32* " + lc_idx_ptr);

        var lc_n: int = this.temp_count;
        this.temp_count = this.temp_count + 1;
        var lc_loop: str = "lc_loop_" + str(lc_n);
        var lc_body: str = "lc_body_" + str(lc_n);
        var lc_end:  str = "lc_end_" + str(lc_n);

        this.emit("  br label %" + lc_loop);
        this.emit(lc_loop + ":");
        var lc_idx: str = this.freshTemp();
        this.emit("  " + lc_idx + " = load i32, i32* " + lc_idx_ptr);
        var lc_cmp: str = this.freshTemp();
        this.emit("  " + lc_cmp + " = icmp slt i32 " + lc_idx + ", " + lc_len);
        this.emit("  br i1 " + lc_cmp + ", label %" + lc_body + ", label %" + lc_end);
        this.emit(lc_body + ":");

        // load the element into the loop variable
        var lc_raw: str = this.allocaAtEntry(lc_src_llvm);
        var lc_rawc: str = this.freshTemp();
        this.emit("  " + lc_rawc + " = bitcast " + lc_src_llvm + "* " + lc_raw + " to i8*");
        this.emit("  call void @mocha_array_get(%MochaArray* " + lc_iter_reg + ", i32 " + lc_idx + ", i8* " + lc_rawc + ")");
        var lc_ld: str = this.freshTemp();
        this.emit("  " + lc_ld + " = load " + lc_src_llvm + ", " + lc_src_llvm + "* " + lc_raw);
        this.emit("  store " + lc_src_llvm + " " + lc_ld + ", " + lc_src_llvm + "* " + lc_elem_ptr);

        var lc_val: str = "";
        if (node.condition != null) {
            var lc_cr: str = this.genExpr(node.condition);
            var lc_ci1: str = this.boolToI1(this.exprReg(lc_cr), this.exprType(lc_cr));
            if (lc_has_else) {
                var lc_then: str  = "lc_then_" + str(lc_n);
                var lc_else: str  = "lc_else_" + str(lc_n);
                var lc_merge: str = "lc_merge_" + str(lc_n);
                var lc_slot: str = this.allocaAtEntry(lc_elem_llvm);
                this.emit("  br i1 " + lc_ci1 + ", label %" + lc_then + ", label %" + lc_else);
                this.emit(lc_then + ":");
                var lc_tr: str = this.genExpr(node.left);
                var lc_treg: str = this.coerceToType(this.exprReg(lc_tr), this.exprType(lc_tr), lc_elem_llvm);
                this.emit("  store " + lc_elem_llvm + " " + lc_treg + ", " + lc_elem_llvm + "* " + lc_slot);
                this.emit("  br label %" + lc_merge);
                this.emit(lc_else + ":");
                var lc_er: str = this.genExpr(node.else_body[0]);
                var lc_ereg: str = this.coerceToType(this.exprReg(lc_er), this.exprType(lc_er), lc_elem_llvm);
                this.emit("  store " + lc_elem_llvm + " " + lc_ereg + ", " + lc_elem_llvm + "* " + lc_slot);
                this.emit("  br label %" + lc_merge);
                this.emit(lc_merge + ":");
                lc_val = this.freshTemp();
                this.emit("  " + lc_val + " = load " + lc_elem_llvm + ", " + lc_elem_llvm + "* " + lc_slot);
            } else {
                var lc_skip:   str = "lc_skip_" + str(lc_n);
                var lc_append: str = "lc_append_" + str(lc_n);
                this.emit("  br i1 " + lc_ci1 + ", label %" + lc_append + ", label %" + lc_skip);
                this.emit(lc_append + ":");
                var lc_fr: str = this.genExpr(node.left);
                lc_val = this.coerceToType(this.exprReg(lc_fr), this.exprType(lc_fr), lc_elem_llvm);
            };
        } else {
            var lc_pr: str = this.genExpr(node.left);
            lc_val = this.coerceToType(this.exprReg(lc_pr), this.exprType(lc_pr), lc_elem_llvm);
        };

        // box (stack slot) and append
        var lc_box: str = this.allocaAtEntry(lc_elem_llvm);
        this.emit("  store " + lc_elem_llvm + " " + lc_val + ", " + lc_elem_llvm + "* " + lc_box);
        var lc_boxed: str = this.freshTemp();
        this.emit("  " + lc_boxed + " = bitcast " + lc_elem_llvm + "* " + lc_box + " to i8*");
        var lc_arr_ld: str = this.freshTemp();
        this.emit("  " + lc_arr_ld + " = load %MochaArray*, %MochaArray** " + lc_arr_ptr);
        this.emit("  call void @mocha_array_push(%MochaArray* " + lc_arr_ld + ", i8* " + lc_boxed + ")");

        if (node.condition != null) {
            if (lc_has_else == false) {
                this.emit("  br label %lc_skip_" + str(lc_n));
                this.emit("lc_skip_" + str(lc_n) + ":");
            };
        };

        var lc_next: str = this.freshTemp();
        this.emit("  " + lc_next + " = add i32 " + lc_idx + ", 1");
        this.emit("  store i32 " + lc_next + ", i32* " + lc_idx_ptr);
        this.emit("  br label %" + lc_loop);
        this.emit(lc_end + ":");

        // put the shadowed outer local back
        if (lc_had) {
            this.declareLocal(node.value, lc_old_p, lc_old_t, lc_old_m);
        };

        var lc_final: str = this.freshTemp();
        this.emit("  " + lc_final + " = load %MochaArray*, %MochaArray** " + lc_arr_ptr);
        return this.exprResult(lc_final, "%MochaArray*");
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