class ASTNode {
    var kind:      str;
    var value:     str;
    var type_str:  str;
    var extra:     str;
    var int_val:   int;
    var real_val: float;
    var imag_val: float;
    var bool_val:  bool;
    var left:      ASTNode;
    var right:     ASTNode;
    var condition: ASTNode;
    var body:      ASTNode[];
    var children:  ASTNode[];
    var params:    ASTNode[];
    var args:      ASTNode[];
    var else_body: ASTNode[];
    var else_ifs:  ASTNode[];
    var cases:     ASTNode[];
    var flag1:     bool;
    var flag2:     bool;
    var is_variadic: bool;

    function constructor() -> null {
        this.kind      = "";
        this.value     = "";
        this.type_str  = "";
        this.extra     = "";
        this.int_val   = 0;
        this.real_val = 0.0;
        this.imag_val = 0.0;
        this.bool_val  = false;
        this.left      = null;
        this.right     = null;
        this.condition = null;
        this.body      = [];
        this.children  = [];
        this.params    = [];
        this.args      = [];
        this.else_body = [];
        this.else_ifs  = [];
        this.cases     = [];
        this.flag1     = false;
        this.flag2     = false;
        this.is_variadic = false;
    };
};

function main(didLoad) -> null {
    print("step 1", newLine=true);
    var n: ASTNode = ASTNode();
    print("step 2", newLine=true);

    var child: ASTNode = ASTNode();
    print("step 3", newLine=true);

    n.body.push(child);
    print("step 4", newLine=true);
    print(n.body.length, newLine=true);

    print("--- DONE ---", newLine=true);
};