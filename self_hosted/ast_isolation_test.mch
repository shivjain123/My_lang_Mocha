from "./ast.mch" import *;

function main(didLoad) -> null {
    print("step 1", newLine=true);
    var n: ASTNode = ASTNode();
    print("step 2", newLine=true);
    n.kind = "test";
    print("step 3", newLine=true);
    print(n.kind, newLine=true);
    print("step 4", newLine=true);

    var child: ASTNode = ASTNode();
    child.kind = "child";
    n.left = child;
    print("step 5", newLine=true);
    print(n.left.kind, newLine=true);

    n.body.push(child);
    print("step 6", newLine=true);
    print(n.body.length, newLine=true);

    print("--- DONE ---", newLine=true);
};