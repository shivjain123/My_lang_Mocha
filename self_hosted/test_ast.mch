from "./ast.mch" import *;

function main(didLoad) -> null {
    // Test basic node creation
    var node: ASTNode = ASTNode();
    node.kind = "IntLiteral";
    node.int_val = 42;
    print(node.kind, newLine=true);       // IntLiteral
    print(node.int_val, newLine=true);    // 42

    // Test complex literal
    var cnode: ASTNode = ASTNode();
    cnode.kind = "ComplexLiteral";
    cnode.real_val = 3.14;
    cnode.imag_val = 2.5;
    print(cnode.real_val, newLine=true);  // 3.14
    print(cnode.imag_val, newLine=true);  // 2.5

    // Test binary op with left and right
    var binop: ASTNode = ASTNode();
    binop.kind = "BinaryOp";
    binop.value = "+";
    binop.left = ASTNode();
    binop.left.kind = "IntLiteral";
    binop.left.int_val = 1;
    binop.right = ASTNode();
    binop.right.kind = "IntLiteral";
    binop.right.int_val = 2;
    print(binop.kind, newLine=true);          // BinaryOp
    print(binop.value, newLine=true);         // +
    print(binop.left.int_val, newLine=true);  // 1
    print(binop.right.int_val, newLine=true); // 2

    // Test children array
    var func: ASTNode = ASTNode();
    func.kind = "FunctionDecl";
    func.value = "add";
    func.type_str = "int";
    var p1: ASTNode = ASTNode();
    p1.kind = "Param";
    p1.value = "x";
    p1.type_str = "int";
    func.params.push(p1);
    print(func.value, newLine=true);              // add
    print(func.params[0].value, newLine=true);    // x
    print(func.params[0].type_str, newLine=true); // int
};