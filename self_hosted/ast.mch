// ============================================================
// ast.mch — AST Node for Mocha Self-Hosted Parser
// One universal node class covering all AST node types
// ============================================================
class ASTNode {
    var kind:      str;
    var value:     str;
    var type_str:  str;
    var extra:     str;
    var int_val:   int;
    var real_val: float;  // FloatLiteral value, ComplexLiteral real part
    var imag_val: float;  // ComplexLiteral imaginary part
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
    var line:      int;
    var col:       int;

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
        this.line      = 0;
        this.col       = 0;
    };
};