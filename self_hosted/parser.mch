// mocha-lib-deps: mocha-string
// ============================================================
// parser.mch — Mocha Self-Hosted Parser
// Converts Token[] into ASTNode tree
// ============================================================

from "./lexer.mch" import *;
from "./ast.mch" import *;

// ============================================================
// Parser Error
// ============================================================

class MochaParseError {
    var message: str;
    var line:    int;
    var col:     int;

    function constructor(msg: str, l: int, c: int) -> null {
        this.message = msg;
        this.line    = l;
        this.col     = c;
    };
};

// ============================================================
// PARSER
// ============================================================

"""
parse_expression
  → parse_assignment
    → parse_or
      → parse_and
        → parse_equality
          → parse_comparison
            → parse_range
              → parse_addition
                → parse_multiplication
                  → parse_unary
                    → parse_postfix
                      → parse_primary
"""

class Parser {
    var tokens: Token[];
    var pos:    int;

    function constructor(toks: Token[]) -> null {
        this.tokens = toks;
        this.pos = 0;
    };

    // --------------------------------------------------------
    // Helpers
    // --------------------------------------------------------

    function current() -> Token {
        if (this.pos < this.tokens.length) {
            return this.tokens[this.pos];
        };
        return this.tokens[this.tokens.length - 1]; // EOF
    };

    function peek(offset: int) -> Token {
        var idx: int = this.pos + offset;
        if (idx < this.tokens.length) {
            return this.tokens[idx];
        };
        return this.tokens[this.tokens.length - 1]; // EOF
    };

    function advance() -> Token {
        var tok: Token = this.current();
        this.pos = this.pos + 1;
        return tok;
    };

    function check(t: TokenType) -> bool {
        return this.current().type == t;
    };

    function pair(t: TokenType) -> bool {
        if (this.check(t)) {
            this.advance();
            return true;
        };
        return false;
    };

    function expect(t: TokenType, msg: str) -> Token {
        if (this.check(t)) {
            return this.advance();
        };
        var err: MochaParseError = MochaParseError(
            msg,
            this.current().line,
            this.current().col
        );
        mocha_error("MochaParseError at line " + str(err.line) + ", col " + str(err.col) + ": " + err.message);
        return this.current(); // dummy
    };

    function parse_error(msg: str) -> null {
        var err: MochaParseError = MochaParseError(
            msg,
            this.current().line,
            this.current().col
        );
        mocha_error("MochaParseError at line " + str(err.line) + ", col " + str(err.col) + ": " + err.message);
    };

    function make_node(kind: str) -> ASTNode {
        var node: ASTNode = ASTNode();
        node.kind = kind;
        var cur: Token = this.current();
        node.line = cur.line;
        node.col = cur.col;
        return node;
    };

    function parse_statement() -> ASTNode {
        match (this.current().type) {
            case TokenType.IMPORT:    return this.parse_import();
            case TokenType.FROM:      return this.parse_import();
            case TokenType.FUNCTION:  return this.parse_function();
            case TokenType.CLASS:     return this.parse_class();
            case TokenType.INTERFACE: return this.parse_interface();
            case TokenType.TAG:       return this.parse_tag();
            case TokenType.EXTEND:    return this.parse_extend();
            case TokenType.VAR:       return this.parse_var();
            case TokenType.CONST:     return this.parse_const();
            case TokenType.RETURN:    return this.parse_return();
            case TokenType.IF:        return this.parse_if();
            case TokenType.WHILE:     return this.parse_while();
            case TokenType.FOR:       return this.parse_for();
            case TokenType.MATCH:     return this.parse_match();
            case TokenType.PRINT:     return this.parse_print();
            case TokenType.BREAK:
                this.advance();
                this.expect(TokenType.SEMICOLON, "Expected ';' after break");
                return this.make_node("BreakStmt");
            case TokenType.CONTINUE:
                this.advance();
                this.expect(TokenType.SEMICOLON, "Expected ';' after continue");
                return this.make_node("ContinueStmt");
            default: return this.parse_expr_stmt();
        };
    };

    function parse_var() -> ASTNode {
        var node: ASTNode = this.make_node("VarDecl");
        this.advance(); // consume 'var'
        var name_tok: Token = this.expect(TokenType.IDENTIFIER, "Expected variable name after 'var'");
        node.value = name_tok.value;
        this.expect(TokenType.COLON, "Expected ':' after variable name");
        node.type_str = this.parse_type_str();
        if (this.pair(TokenType.ASSIGN)) {
            node.left = this.parse_expression();
        };
        this.expect(TokenType.SEMICOLON, "Expected ';' after variable declaration");
        return node;
    };

    function parse_const() -> ASTNode {
        var node: ASTNode = this.make_node("ConstDecl");
        this.advance(); // consume 'const'
        var name_tok: Token = this.expect(TokenType.CONST_IDENT, "Expected constant name after 'const'");
        node.value = name_tok.value;
        this.expect(TokenType.COLON, "Expected ':' after constant name");
        node.type_str = this.parse_type_str();
        this.expect(TokenType.ASSIGN, "Expected '=' after constant type");
        node.left = this.parse_expression();
        this.expect(TokenType.SEMICOLON, "Expected ';' after constant declaration");
        return node;
    };

    function parse_type_str() -> str {
        // Tuple type: (float[][], 3)
        if (this.check(TokenType.LPAREN)) {
            this.advance(); // consume '('
            var inner: str = this.parse_type_str();
            var result: str = "(" + inner;
            if (this.pair(TokenType.COMMA)) {
                var count_tok: Token = this.expect(TokenType.INT_LIT, "Expected count in tuple type");
                result = result + ", " + count_tok.value;
            };
            this.expect(TokenType.RPAREN, "Expected ')' to close tuple type");
            return result + ")";
        };

        // Normal type
        var tok: Token = this.current();
        var type_name: str = tok.value;
        this.advance();

        // Array suffix []
        while (this.check(TokenType.LBRACKET)) {
            this.advance();
            this.expect(TokenType.RBRACKET, "Expected ']' in type annotation");
            type_name = type_name + "[]";
        };

        return type_name;
    };

    function parse_return() -> ASTNode {
        var node: ASTNode = this.make_node("ReturnStmt");
        this.advance(); // consume 'return'
        if (!this.check(TokenType.SEMICOLON)) {
            node.left = this.parse_expression();
        };
        this.expect(TokenType.SEMICOLON, "Expected ';' after return");
        return node;
    };

    function parse_if() -> ASTNode {
        var node: ASTNode = this.make_node("IfStmt");
        this.advance(); // consume 'if'
        this.expect(TokenType.LPAREN, "Expected '(' after 'if'");
        node.condition = this.parse_expression();
        this.expect(TokenType.RPAREN, "Expected ')' after if condition");
        this.expect(TokenType.LBRACE, "Expected '{' to open if body");
        while (!this.check(TokenType.RBRACE) && !this.check(TokenType.EOF)) {
            node.body.push(this.parse_statement());
        };
        this.expect(TokenType.RBRACE, "Expected '}' to close if body");
        this.pair(TokenType.SEMICOLON);

        // else if / else
        while (this.check(TokenType.ELSE)) {
            this.advance(); // consume 'else'
            if (this.check(TokenType.IF)) {
                // else if
                var elif_node: ASTNode = this.make_node("ElseIf");
                this.advance(); // consume 'if'
                this.expect(TokenType.LPAREN, "Expected '(' after 'else if'");
                elif_node.condition = this.parse_expression();
                this.expect(TokenType.RPAREN, "Expected ')' after else if condition");
                this.expect(TokenType.LBRACE, "Expected '{' to open else if body");
                while (!this.check(TokenType.RBRACE) && !this.check(TokenType.EOF)) {
                    elif_node.body.push(this.parse_statement());
                };
                this.expect(TokenType.RBRACE, "Expected '}' to close else if body");
                this.pair(TokenType.SEMICOLON);
                node.else_ifs.push(elif_node);
            } else {
                // else
                this.expect(TokenType.LBRACE, "Expected '{' to open else body");
                while (!this.check(TokenType.RBRACE) && !this.check(TokenType.EOF)) {
                    node.else_body.push(this.parse_statement());
                };
                this.expect(TokenType.RBRACE, "Expected '}' to close else body");
                this.pair(TokenType.SEMICOLON);
                break;
            };
        };
        return node;
    };
    function parse_while() -> ASTNode {
        var node: ASTNode = this.make_node("WhileLoop");
        this.advance(); // consume 'while'
        this.expect(TokenType.LPAREN, "Expected '(' after 'while'");
        node.condition = this.parse_expression();
        this.expect(TokenType.RPAREN, "Expected ')' after while condition");
        this.expect(TokenType.LBRACE, "Expected '{' to open while body");
        while (!this.check(TokenType.RBRACE) && !this.check(TokenType.EOF)) {
            node.body.push(this.parse_statement());
        };
        this.expect(TokenType.RBRACE, "Expected '}' to close while body");
        this.pair(TokenType.SEMICOLON);
        return node;
    };
    function parse_for() -> ASTNode {
        this.advance(); // consume 'for'
        
        // for each loop
        if (this.check(TokenType.EACH)) {
            this.advance(); // consume 'each'
            var node: ASTNode = this.make_node("ForEachLoop");
            var var_tok: Token = this.expect(TokenType.IDENTIFIER, "Expected variable name after 'each'");
            node.value = var_tok.value;
            this.expect(TokenType.IN, "Expected 'in' after variable name");
            node.left = this.parse_expression();
            this.expect(TokenType.LBRACE, "Expected '{' to open for each body");
            while (!this.check(TokenType.RBRACE) && !this.check(TokenType.EOF)) {
                node.body.push(this.parse_statement());
            };
            this.expect(TokenType.RBRACE, "Expected '}' to close for each body");
            this.pair(TokenType.SEMICOLON);
            return node;
        };

        // regular for loop
        var node: ASTNode = this.make_node("ForLoop");
        this.expect(TokenType.LPAREN, "Expected '(' after 'for'");
        node.left = this.parse_statement();   // init
        node.condition = this.parse_expression();
        this.expect(TokenType.SEMICOLON, "Expected ';' after for condition");
        node.right = this.parse_expression(); // step
        this.expect(TokenType.RPAREN, "Expected ')' after for clauses");
        this.expect(TokenType.LBRACE, "Expected '{' to open for body");
        while (!this.check(TokenType.RBRACE) && !this.check(TokenType.EOF)) {
            node.body.push(this.parse_statement());
        };
        this.expect(TokenType.RBRACE, "Expected '}' to close for body");
        this.pair(TokenType.SEMICOLON);
        return node;
    };
    function parse_match() -> ASTNode {
        var node: ASTNode = this.make_node("MatchStmt");
        this.advance(); // consume 'match'
        this.expect(TokenType.LPAREN, "Expected '(' after 'match'");
        node.left = this.parse_expression();
        this.expect(TokenType.RPAREN, "Expected ')' after match value");
        this.expect(TokenType.LBRACE, "Expected '{' to open match body");

        while (!this.check(TokenType.RBRACE) && !this.check(TokenType.EOF)) {
            var case_node: ASTNode = this.make_node("CaseNode");

            if (this.check(TokenType.DEFAULT)) {
                this.advance();
                case_node.flag1 = true; // is_default
            } else {
                this.expect(TokenType.CASE, "Expected 'case' or 'default' in match");
                case_node.left = this.parse_expression(); // pattern
                if (this.check(TokenType.WHEN)) {
                    this.advance();
                    case_node.condition = this.parse_expression();
                };
            };

            this.expect(TokenType.COLON, "Expected ':' after case pattern");

            // body — statements until next case/default/}
            while (!this.check(TokenType.CASE) && !this.check(TokenType.DEFAULT) &&
                !this.check(TokenType.RBRACE) && !this.check(TokenType.EOF)) {
                case_node.body.push(this.parse_statement());
            };

            node.cases.push(case_node);
        };

        this.expect(TokenType.RBRACE, "Expected '}' to close match");
        this.pair(TokenType.SEMICOLON);
        return node;
    };

    function parse_function() -> ASTNode {
        var node: ASTNode = this.make_node("FunctionDecl");
        this.advance(); // consume 'function'

        // async?
        if (this.check(TokenType.ASYNC)) {
            this.advance();
            node.flag1 = true; // is_async
        };

        var name_tok: Token = this.expect(TokenType.IDENTIFIER, "Expected function name");
        node.value = name_tok.value;

        this.expect(TokenType.LPAREN, "Expected '(' after function name");

        // params
        while (!this.check(TokenType.RPAREN) && !this.check(TokenType.EOF)) {
            if (this.check(TokenType.DID_LOAD)) {
                this.advance();
                var dl_node: ASTNode = this.make_node("Param");
                dl_node.value = "didLoad";
                dl_node.flag1 = true; // has_didLoad
                node.params.push(dl_node);
            } else if (this.check(TokenType.PLUS)) {
                this.advance(); // consume '+'
                node.is_variadic = true;
                break; // must be last
            } else {
                var param: ASTNode = this.make_node("Param");
                var p_tok: Token = this.expect(TokenType.IDENTIFIER, "Expected parameter name");
                param.value = p_tok.value;
                this.expect(TokenType.COLON, "Expected ':' after parameter name");
                param.type_str = this.parse_type_str();
                node.params.push(param);
            };
            if (!this.check(TokenType.RPAREN) && !this.check(TokenType.PLUS)) {
                this.expect(TokenType.COMMA, "Expected ',' between parameters");
            };
        };

        this.expect(TokenType.RPAREN, "Expected ')' after parameters");
        this.expect(TokenType.ARROW, "Expected '->' after parameters");
        node.type_str = this.parse_type_str(); // return type

        // native?
        if (this.check(TokenType.NATIVE)) {
            this.advance();
            var native_tok: Token = this.expect(TokenType.IDENTIFIER, "Expected native function name");
            node.extra = native_tok.value; // native_name
            node.flag2 = true; // is_native
            this.expect(TokenType.SEMICOLON, "Expected ';' after native declaration");
            return node;
        };

        // body
        this.expect(TokenType.LBRACE, "Expected '{' to open function body");
        while (!this.check(TokenType.RBRACE) && !this.check(TokenType.EOF)) {
            node.body.push(this.parse_statement());
        };
        this.expect(TokenType.RBRACE, "Expected '}' to close function body");
        this.pair(TokenType.SEMICOLON);
        return node;
    };

    function parse_class() -> ASTNode {
        var node: ASTNode = this.make_node("ClassDecl");
        this.advance(); // consume 'class'

        var name_tok: Token = this.expect(TokenType.IDENTIFIER, "Expected class name");
        node.value = name_tok.value;

        // extends
        if (this.check(TokenType.EXTENDS)) {
            this.advance();
            var parent: ASTNode = this.make_node("Parent");
            var p_tok: Token = this.expect(TokenType.IDENTIFIER, "Expected parent class name");
            parent.value = p_tok.value;
            node.children.push(parent);
            while (this.pair(TokenType.COMMA)) {
                var p2: ASTNode = this.make_node("Parent");
                var p2_tok: Token = this.expect(TokenType.IDENTIFIER, "Expected parent class name");
                p2.value = p2_tok.value;
                node.children.push(p2);
            };
        };

        // implements
        if (this.check(TokenType.IMPLEMENTS)) {
            this.advance();
            var iface: ASTNode = this.make_node("Interface");
            var i_tok: Token = this.expect(TokenType.IDENTIFIER, "Expected interface name");
            iface.value = i_tok.value;
            node.else_ifs.push(iface); // reuse else_ifs for interfaces
            while (this.pair(TokenType.COMMA)) {
                var i2: ASTNode = this.make_node("Interface");
                var i2_tok: Token = this.expect(TokenType.IDENTIFIER, "Expected interface name");
                i2.value = i2_tok.value;
                node.else_ifs.push(i2);
            };
        };

        this.expect(TokenType.LBRACE, "Expected '{' to open class body");

        while (!this.check(TokenType.RBRACE) && !this.check(TokenType.EOF)) {
            // visibility modifier
            var visibility: str = "public";
            if (this.check(TokenType.PRIVATE)) {
                this.advance();
                visibility = "private";
            } else if (this.check(TokenType.PROTECTED)) {
                this.advance();
                visibility = "protected";
            };

            // shared
            var is_shared: bool = false;
            if (this.check(TokenType.SHARED)) {
                this.advance();
                is_shared = true;
            };

            // field
            if (this.check(TokenType.VAR)) {
                this.advance();
                var field: ASTNode = this.make_node("FieldDecl");
                var f_tok: Token = this.expect(TokenType.IDENTIFIER, "Expected field name");
                field.value = f_tok.value;
                this.expect(TokenType.COLON, "Expected ':' after field name");
                field.type_str = this.parse_type_str();
                field.extra = visibility;
                if (this.pair(TokenType.ASSIGN)) {
                    field.left = this.parse_expression();
                };
                this.expect(TokenType.SEMICOLON, "Expected ';' after field declaration");
                node.body.push(field);

            // method
            } else if (this.check(TokenType.FUNCTION)) {
                var method: ASTNode = this.parse_function();
                method.kind = "MethodDecl";
                method.extra = visibility;
                method.flag1 = is_shared;
                node.body.push(method);
            } else {
                this.parse_error("Expected field or method in class body");
                this.advance(); // skip unknown token
            };
        };

        this.expect(TokenType.RBRACE, "Expected '}' to close class body");
        this.pair(TokenType.SEMICOLON);
        return node;
    };
    function parse_interface() -> ASTNode {
        var node: ASTNode = this.make_node("InterfaceDecl");
        this.advance(); // consume 'interface'
        var name_tok: Token = this.expect(TokenType.IDENTIFIER, "Expected interface name");
        node.value = name_tok.value;
        this.expect(TokenType.LBRACE, "Expected '{' to open interface body");

        while (!this.check(TokenType.RBRACE) && !this.check(TokenType.EOF)) {
            this.expect(TokenType.FUNCTION, "Expected 'function' in interface body");
            var method: ASTNode = this.make_node("InterfaceMethod");
            var m_tok: Token = this.expect(TokenType.IDENTIFIER, "Expected method name");
            method.value = m_tok.value;
            this.expect(TokenType.LPAREN, "Expected '(' after method name");
            while (!this.check(TokenType.RPAREN) && !this.check(TokenType.EOF)) {
                var param: ASTNode = this.make_node("Param");
                var p_tok: Token = this.expect(TokenType.IDENTIFIER, "Expected parameter name");
                param.value = p_tok.value;
                this.expect(TokenType.COLON, "Expected ':' after parameter name");
                param.type_str = this.parse_type_str();
                method.params.push(param);
                if (!this.check(TokenType.RPAREN)) {
                    this.expect(TokenType.COMMA, "Expected ',' between parameters");
                };
            };
            this.expect(TokenType.RPAREN, "Expected ')' after parameters");
            this.expect(TokenType.ARROW, "Expected '->' after parameters");
            method.type_str = this.parse_type_str();
            this.expect(TokenType.SEMICOLON, "Expected ';' after interface method");
            node.body.push(method);
        };

        this.expect(TokenType.RBRACE, "Expected '}' to close interface");
        this.pair(TokenType.SEMICOLON);
        return node;
    };

    function parse_tag() -> ASTNode {
        var node: ASTNode = this.make_node("TagDecl");
        this.advance(); // consume 'tag'
        var name_tok: Token = this.expect(TokenType.IDENTIFIER, "Expected tag name");
        node.value = name_tok.value;
        this.expect(TokenType.LBRACE, "Expected '{' to open tag body");

        while (!this.check(TokenType.RBRACE) && !this.check(TokenType.EOF)) {
            var member: ASTNode = this.make_node("TagMember");
            var m_tok: Token = this.expect(TokenType.CONST_IDENT, "Expected tag member name");
            member.value = m_tok.value;
            node.children.push(member);
            if (!this.check(TokenType.RBRACE)) {
                this.expect(TokenType.COMMA, "Expected ',' between tag members");
            };
        };

        this.expect(TokenType.RBRACE, "Expected '}' to close tag");
        this.pair(TokenType.SEMICOLON);
        return node;
    };

    function parse_extend() -> ASTNode {
        var node: ASTNode = this.make_node("ExtendDecl");
        this.advance(); // consume 'extend'
        node.value = this.parse_type_str(); // type being extended
        this.expect(TokenType.LBRACE, "Expected '{' to open extend body");

        while (!this.check(TokenType.RBRACE) && !this.check(TokenType.EOF)) {
            this.expect(TokenType.FUNCTION, "Expected 'function' in extend body");
            var func: ASTNode = this.parse_function();
            func.kind = "ExtendMethod";
            node.body.push(func);
        };

        this.expect(TokenType.RBRACE, "Expected '}' to close extend");
        this.pair(TokenType.SEMICOLON);
        return node;
    };

    function parse_import() -> ASTNode {
        var node: ASTNode = this.make_node("ImportStmt");

        // syntax 1: import ModuleName from "source" as alias;
        if (this.check(TokenType.IMPORT)) {
            this.advance(); // consume 'import'
            // from "source" import *
            if (this.check(TokenType.FROM)) {
                this.advance(); // consume 'from'
                var src_tok: Token = this.expect(TokenType.STR_LIT, "Expected source string");
                node.type_str = src_tok.value; // source
                this.expect(TokenType.IMPORT, "Expected 'import' after source");
                this.expect(TokenType.STAR, "Expected '*' after import");  
                this.expect(TokenType.SEMICOLON, "Expected ';' after import");
                node.value = "*";
                return node;
            };
            var mod_tok: Token = this.expect(TokenType.IDENTIFIER, "Expected module name");
            node.value = mod_tok.value; // module name
            this.expect(TokenType.FROM, "Expected 'from' after module name");
            var src_tok2: Token = this.expect(TokenType.STR_LIT, "Expected source string");
            node.type_str = src_tok2.value; // source
            if (this.check(TokenType.AS)) {
                this.advance();
                var alias_tok: Token = this.expect(TokenType.IDENTIFIER, "Expected alias after 'as'");
                node.extra = alias_tok.value; // alias
            };
            this.expect(TokenType.SEMICOLON, "Expected ';' after import");
            return node;
        };

        // syntax 2: from "source" import *;
        this.advance(); // consume 'from'
        var src_tok3: Token = this.expect(TokenType.STR_LIT, "Expected source string");
        node.type_str = src_tok3.value; // source
        this.expect(TokenType.IMPORT, "Expected 'import' after source");
        this.expect(TokenType.STAR, "Expected '*'");
        this.expect(TokenType.SEMICOLON, "Expected ';' after import");
        node.value = "*";
        return node;
    };

    function parse_print() -> ASTNode {
        var node: ASTNode = this.make_node("PrintStmt");
        this.advance(); // consume 'print'
        this.expect(TokenType.LPAREN, "Expected '(' after 'print'");

        while (!this.check(TokenType.RPAREN) && !this.check(TokenType.EOF)) {
            if (this.check(TokenType.NEWLINE_ARG)) {
                this.advance();
                this.expect(TokenType.ASSIGN, "Expected '=' after 'newLine'");
                var nl_val: ASTNode = this.parse_expression();
                var nl_node: ASTNode = this.make_node("PrintArg");
                nl_node.value = "newLine";
                nl_node.left = nl_val;
                node.args.push(nl_node);
            } else if (this.check(TokenType.START_ARG)) {
                this.advance();
                this.expect(TokenType.ASSIGN, "Expected '=' after 'start'");
                var st_val: ASTNode = this.parse_expression();
                var st_node: ASTNode = this.make_node("PrintArg");
                st_node.value = "start";
                st_node.left = st_val;
                node.args.push(st_node);
            } else {
                node.args.push(this.parse_expression());
            };
            if (!this.check(TokenType.RPAREN)) {
                this.expect(TokenType.COMMA, "Expected ',' between print arguments");
            };
        };

        this.expect(TokenType.RPAREN, "Expected ')' after print arguments");
        this.expect(TokenType.SEMICOLON, "Expected ';' after print statement");
        return node;
    };

    function parse_expr_stmt() -> ASTNode {
        var node: ASTNode = this.make_node("ExprStmt");
        node.left = this.parse_expression();
        this.expect(TokenType.SEMICOLON, "Expected ';' after expression");
        return node;
    };

    function parse_expression() -> ASTNode {
        return this.parse_assignment();
    };

    function parse_assignment() -> ASTNode {
        var left: ASTNode = this.parse_or();

        // Assignment
        if (this.check(TokenType.ASSIGN)) {
            this.advance();
            var val: ASTNode = this.parse_assignment();
            var node: ASTNode = this.make_node("Assignment");
            node.left = left;
            node.right = val;
            return node;
        };

        // Compound assignment
        if (this.check(TokenType.PLUS_ASSIGN) || this.check(TokenType.MINUS_ASSIGN) ||
            this.check(TokenType.STAR_ASSIGN) || this.check(TokenType.SLASH_ASSIGN)) {
            var op_tok: Token = this.advance();
            var val2: ASTNode = this.parse_assignment();
            var node2: ASTNode = this.make_node("CompoundAssignment");
            node2.left = left;
            node2.value = op_tok.value;
            node2.right = val2;
            return node2;
        };

        return left;
    };

    function parse_or() -> ASTNode {
        var left: ASTNode = this.parse_and();
        while (this.check(TokenType.OR)) {
            var op_tok: Token = this.advance();
            var right: ASTNode = this.parse_and();
            var node: ASTNode = this.make_node("BinaryOp");
            node.left = left;
            node.value = op_tok.value;
            node.right = right;
            left = node;
        };
        return left;
    };

    function parse_and() -> ASTNode {
        var left: ASTNode = this.parse_equality();
        while (this.check(TokenType.AND)) {
            var op_tok: Token = this.advance();
            var right: ASTNode = this.parse_equality();
            var node: ASTNode = this.make_node("BinaryOp");
            node.left = left;
            node.value = op_tok.value;
            node.right = right;
            left = node;
        };
        return left;
    };

    function parse_equality() -> ASTNode {
        var left: ASTNode = this.parse_comparison();
        while (this.check(TokenType.EQ) || this.check(TokenType.NEQ)) {
            var op_tok: Token = this.advance();
            var right: ASTNode = this.parse_comparison();
            var node: ASTNode = this.make_node("BinaryOp");
            node.left = left;
            node.value = op_tok.value;
            node.right = right;
            left = node;
        };
        return left;
    };

    function parse_comparison() -> ASTNode {
        var left: ASTNode = this.parse_range();
        while (this.check(TokenType.LT) || this.check(TokenType.GT) ||
            this.check(TokenType.LTE) || this.check(TokenType.GTE)) {
            var op_tok: Token = this.advance();
            var right: ASTNode = this.parse_range();
            var node: ASTNode = this.make_node("BinaryOp");
            node.left = left;
            node.value = op_tok.value;
            node.right = right;
            left = node;
        };
        return left;
    };

    function parse_range() -> ASTNode {
        var left: ASTNode = this.parse_addition();
        if (this.check(TokenType.RANGE)) {
            this.advance();
            var right: ASTNode = this.parse_addition();
            var node: ASTNode = this.make_node("RangeNode");
            node.left = left;
            node.right = right;
            return node;
        };
        return left;
    };

    function parse_addition() -> ASTNode {
        var left: ASTNode = this.parse_multiplication();
        while (this.check(TokenType.PLUS) || this.check(TokenType.MINUS)) {
            var op_tok: Token = this.advance();
            var right: ASTNode = this.parse_multiplication();
            var node: ASTNode = this.make_node("BinaryOp");
            node.left = left;
            node.value = op_tok.value;
            node.right = right;
            left = node;
        };
        return left;
    };

    function parse_multiplication() -> ASTNode {
        var left: ASTNode = this.parse_unary();
        while (this.check(TokenType.STAR) || this.check(TokenType.SLASH) ||
            this.check(TokenType.PERCENT)) {
            var op_tok: Token = this.advance();
            var right: ASTNode = this.parse_unary();
            var node: ASTNode = this.make_node("BinaryOp");
            node.left = left;
            node.value = op_tok.value;
            node.right = right;
            left = node;
        };
        return left;
    };

    function parse_unary() -> ASTNode {
        if (this.check(TokenType.NOT)) {
            var op_tok: Token = this.advance();
            var node: ASTNode = this.make_node("UnaryOp");
            node.value = op_tok.value;
            node.right = this.parse_unary();
            return node;
        };
        if (this.check(TokenType.MINUS)) {
            var op_tok2: Token = this.advance();
            var node2: ASTNode = this.make_node("UnaryOp");
            node2.value = "-";
            node2.right = this.parse_unary();
            return node2;
        };
        if (this.check(TokenType.PLUS_PLUS)) {
            var op_tok3: Token = this.advance();
            var node3: ASTNode = this.make_node("PreIncrement");
            node3.value = "++";
            node3.right = this.parse_unary();
            return node3;
        };
        if (this.check(TokenType.MINUS_MINUS)) {
            var op_tok4: Token = this.advance();
            var node4: ASTNode = this.make_node("PreDecrement");
            node4.value = "--";
            node4.right = this.parse_unary();
            return node4;
        };
        return this.parse_postfix();
    };

    function parse_postfix() -> ASTNode {
        var expr: ASTNode = this.parse_primary();

        while (true) {
            // post increment/decrement
            if (this.check(TokenType.PLUS_PLUS)) {
                this.advance();
                var node: ASTNode = this.make_node("PostIncrement");
                node.left = expr;
                node.value = "++";
                expr = node;
            } else if (this.check(TokenType.MINUS_MINUS)) {
                this.advance();
                var node2: ASTNode = this.make_node("PostIncrement");
                node2.left = expr;
                node2.value = "--";
                expr = node2;
            // member access
            } else if (this.check(TokenType.DOT)) {
                this.advance();
                var mem_tok: Token = this.expect(TokenType.IDENTIFIER, "Expected member name after '.'");
                var node3: ASTNode = this.make_node("MemberAccess");
                node3.left = expr;
                node3.value = mem_tok.value;
                expr = node3;
            // index access
            } else if (this.check(TokenType.LBRACKET)) {
                this.advance();
                // check for 2D col slice [][c]
                if (this.check(TokenType.RBRACKET)) {
                    this.advance();
                    this.expect(TokenType.LBRACKET, "Expected '[' for col slice");
                    var col_idx: ASTNode = this.parse_expression();
                    this.expect(TokenType.RBRACKET, "Expected ']' after col index");
                    var node4: ASTNode = this.make_node("ColSlice");
                    node4.left = expr;
                    node4.right = col_idx;
                    expr = node4;
                } else {
                    var idx: ASTNode = this.parse_expression();
                    this.expect(TokenType.RBRACKET, "Expected ']' after index");
                    // check for 2D [r][]
                    if (this.check(TokenType.LBRACKET)) {
                        this.advance();
                        if (this.check(TokenType.RBRACKET)) {
                            this.advance();
                            var node5: ASTNode = this.make_node("RowSlice");
                            node5.left = expr;
                            node5.right = idx;
                            expr = node5;
                        } else {
                            var col_idx2: ASTNode = this.parse_expression();
                            this.expect(TokenType.RBRACKET, "Expected ']' after col index");
                            var node6: ASTNode = this.make_node("Index2DAccess");
                            node6.left = expr;
                            node6.condition = idx;
                            node6.right = col_idx2;
                            expr = node6;
                        };
                    } else {
                        var node7: ASTNode = this.make_node("IndexAccess");
                        node7.left = expr;
                        node7.right = idx;
                        expr = node7;
                    };
                };
            // tuple access #
            } else if (this.check(TokenType.HASH)) {
                this.advance();
                var idx_tok: Token = this.expect(TokenType.INT_LIT, "Expected index after '#'");
                var node8: ASTNode = this.make_node("TupleAccess");
                node8.left = expr;
                node8.int_val = idx_tok.value.toInt();
                expr = node8;
            // function call
            } else if (this.check(TokenType.LPAREN)) {
                this.advance();
                var call_node: ASTNode = this.make_node("FunctionCall");
                call_node.left = expr;
                while (!this.check(TokenType.RPAREN) && !this.check(TokenType.EOF)) {
                    if (this.check(TokenType.NEWLINE_ARG)) {
                        this.advance();
                        this.expect(TokenType.ASSIGN, "Expected '=' after 'newLine'");
                        var nl_val: ASTNode = this.parse_expression();
                        var nl_node: ASTNode = this.make_node("NamedArg");
                        nl_node.value = "newLine";
                        nl_node.left = nl_val;
                        call_node.args.push(nl_node);
                    } else if (this.check(TokenType.START_ARG)) {
                        this.advance();
                        this.expect(TokenType.ASSIGN, "Expected '=' after 'start'");
                        var st_val: ASTNode = this.parse_expression();
                        var st_node: ASTNode = this.make_node("NamedArg");
                        st_node.value = "start";
                        st_node.left = st_val;
                        call_node.args.push(st_node);
                    } else {
                        call_node.args.push(this.parse_expression());
                    };
                    if (!this.check(TokenType.RPAREN)) {
                        this.expect(TokenType.COMMA, "Expected ',' between arguments");
                    };
                };
                this.expect(TokenType.RPAREN, "Expected ')' after arguments");
                expr = call_node;
            } else {
                break;
            };
        };
        return expr;
    };

    function parse_lambda() -> ASTNode {
        var node: ASTNode = this.make_node("LambdaExpr");
        this.advance(); // consume 'lambda'
        this.expect(TokenType.LPAREN, "Expected '(' after 'lambda'");

        // params
        while (!this.check(TokenType.RPAREN) && !this.check(TokenType.EOF)) {
            var param: ASTNode = this.make_node("Param");
            var p_tok: Token = this.expect(TokenType.IDENTIFIER, "Expected parameter name");
            param.value = p_tok.value;
            this.expect(TokenType.COLON, "Expected ':' after parameter name");
            param.type_str = this.parse_type_str();
            node.params.push(param);
            if (!this.check(TokenType.RPAREN)) {
                this.expect(TokenType.COMMA, "Expected ',' between lambda parameters");
            };
        };

        this.expect(TokenType.RPAREN, "Expected ')' after lambda parameters");
        this.expect(TokenType.ARROW, "Expected '->' after lambda parameters");
        node.type_str = this.parse_type_str(); // return type
        this.expect(TokenType.COLON, "Expected ':' after lambda return type");
        node.left = this.parse_expression(); // lambda body — single expression
        return node;
    };

    function parse_primary() -> ASTNode {
        var tok: Token = this.current();

        match (tok.type) {
            case TokenType.INT_LIT:
                this.advance();
                var int_node: ASTNode = this.make_node("IntLiteral");
                int_node.int_val = tok.value.toInt();
                return int_node;
            case TokenType.FLOAT_LIT:
                this.advance();
                var float_node: ASTNode = this.make_node("FloatLiteral");
                float_node.real_val = tok.value.toFloat();
                return float_node;
            case TokenType.COMPLEX_LIT:
                this.advance();
                var complex_node: ASTNode = this.make_node("ComplexLiteral");
                complex_node.real_val = tok.value.toFloat();
                return complex_node;
            case TokenType.STR_LIT:
                this.advance();
                var str_node: ASTNode = this.make_node("StrLiteral");
                str_node.value = tok.value;
                return str_node;
            case TokenType.BOOL_LIT:
                this.advance();
                var bool_node: ASTNode = this.make_node("BoolLiteral");
                bool_node.bool_val = tok.value == "true";
                return bool_node;
            case TokenType.IDENTIFIER:
                this.advance();
                var ident_node: ASTNode = this.make_node("Identifier");
                ident_node.value = tok.value;
                return ident_node;
            case TokenType.CONST_IDENT:
                this.advance();
                var const_node: ASTNode = this.make_node("Identifier");
                const_node.value = tok.value;
                const_node.flag1 = true;
                return const_node;
            case TokenType.TYPE_INT:
                this.advance();
                var cast_int_node: ASTNode = this.make_node("TypeCast");
                cast_int_node.value = tok.value;
                this.expect(TokenType.LPAREN, "Expected '(' after type cast");
                cast_int_node.left = this.parse_expression();
                this.expect(TokenType.RPAREN, "Expected ')' after type cast");
                return cast_int_node;
            case TokenType.TYPE_FLOAT:
                this.advance();
                var cast_float_node: ASTNode = this.make_node("TypeCast");
                cast_float_node.value = tok.value;
                this.expect(TokenType.LPAREN, "Expected '(' after type cast");
                cast_float_node.left = this.parse_expression();
                this.expect(TokenType.RPAREN, "Expected ')' after type cast");
                return cast_float_node;
            case TokenType.TYPE_STR:
                this.advance();
                var cast_str_node: ASTNode = this.make_node("TypeCast");
                cast_str_node.value = tok.value;
                this.expect(TokenType.LPAREN, "Expected '(' after type cast");
                cast_str_node.left = this.parse_expression();
                this.expect(TokenType.RPAREN, "Expected ')' after type cast");
                return cast_str_node;
            case TokenType.TYPE_BOOL:
                this.advance();
                var cast_bool_node: ASTNode = this.make_node("TypeCast");
                cast_bool_node.value = tok.value;
                this.expect(TokenType.LPAREN, "Expected '(' after type cast");
                cast_bool_node.left = this.parse_expression();
                this.expect(TokenType.RPAREN, "Expected ')' after type cast");
                return cast_bool_node;
            case TokenType.TYPE_VAST:
                this.advance();
                var cast_vast_node: ASTNode = this.make_node("TypeCast");
                cast_vast_node.value = tok.value;
                this.expect(TokenType.LPAREN, "Expected '(' after type cast");
                cast_vast_node.left = this.parse_expression();
                this.expect(TokenType.RPAREN, "Expected ')' after type cast");
                return cast_vast_node;
            case TokenType.THIS:
                this.advance();
                return this.make_node("This");
            case TokenType.ALLOC:
                this.advance();
                var alloc_node: ASTNode = this.make_node("AllocArray");
                alloc_node.value = this.parse_type_str();
                this.expect(TokenType.LBRACKET, "Expected '[' after alloc type");
                alloc_node.left = this.parse_expression();
                this.expect(TokenType.RBRACKET, "Expected ']' after alloc size");
                if (this.check(TokenType.LBRACKET)) {
                    this.advance();
                    alloc_node.right = this.parse_expression();
                    this.expect(TokenType.RBRACKET, "Expected ']' after 2D alloc size");
                };
                return alloc_node;
            case TokenType.OK:
                this.advance();
                this.expect(TokenType.LPAREN, "Expected '(' after 'ok'");
                var ok_node: ASTNode = this.make_node("OkExpr");
                ok_node.left = this.parse_expression();
                this.expect(TokenType.RPAREN, "Expected ')' after ok value");
                return ok_node;
            case TokenType.ERROR:
                this.advance();
                this.expect(TokenType.LPAREN, "Expected '(' after 'error'");
                var err_node: ASTNode = this.make_node("ErrorExpr");
                err_node.left = this.parse_expression();
                this.expect(TokenType.RPAREN, "Expected ')' after error value");
                return err_node;
            case TokenType.LAMBDA:
                return this.parse_lambda();
            case TokenType.AWAIT:
                this.advance();
                var await_node: ASTNode = this.make_node("AwaitExpr");
                await_node.left = this.parse_expression();
                return await_node;
            case TokenType.LPAREN:
                this.advance();
                var paren_first: ASTNode = this.parse_expression();
                if (this.check(TokenType.COMMA)) {
                    var tuple_node: ASTNode = this.make_node("TupleLiteral");
                    tuple_node.children.push(paren_first);
                    while (this.pair(TokenType.COMMA)) {
                        tuple_node.children.push(this.parse_expression());
                    };
                    this.expect(TokenType.RPAREN, "Expected ')' to close tuple");
                    return tuple_node;
                };
                this.expect(TokenType.RPAREN, "Expected ')' to close grouped expression");
                return paren_first;
            case TokenType.LBRACKET:
                this.advance();
                if (this.check(TokenType.RBRACKET)) {
                    this.advance();
                    return this.make_node("ArrayLiteral");
                };
                var bracket_first: ASTNode = this.parse_expression();
                var has_if: bool = false;
                var cond_expr: ASTNode = this.make_node("NullLiteral");
                if (this.check(TokenType.IF)) {
                    this.advance();
                    cond_expr = this.parse_expression();
                    has_if = true;
                };
                if (this.check(TokenType.FOR)) {
                    this.advance();
                    this.expect(TokenType.EACH, "Expected 'each' after 'for' in comprehension");
                    var comp_var_tok: Token = this.expect(TokenType.IDENTIFIER, "Expected variable name");
                    this.expect(TokenType.IN, "Expected 'in' after variable name");
                    var iter_expr: ASTNode = this.parse_expression();
                    this.expect(TokenType.RBRACKET, "Expected ']' to close comprehension");
                    var lc_node: ASTNode = this.make_node("ListComprehension");
                    lc_node.left = bracket_first;
                    lc_node.value = comp_var_tok.value;
                    lc_node.right = iter_expr;
                    if (has_if) {
                        lc_node.condition = cond_expr;
                        // check for else branch
                        if (this.check(TokenType.ELSE)) {
                            this.advance();
                            var else_expr: ASTNode = this.parse_expression();
                            lc_node.else_body.push(else_expr);
                        };
                    };
                };
                var arr_node: ASTNode = this.make_node("ArrayLiteral");
                arr_node.children.push(bracket_first);
                while (this.pair(TokenType.COMMA)) {
                    arr_node.children.push(this.parse_expression());
                };
                this.expect(TokenType.RBRACKET, "Expected ']' to close array literal");
                return arr_node;
            default:
                this.parse_error("Expected an expression. Got: " + tok.value);
                return this.make_node("Unknown");
        };
    };

    function parse() -> ASTNode {
        var prog: ASTNode = this.make_node("Program");
        var done: bool = this.check(TokenType.EOF);
        while (!done) {
            prog.children.push(this.parse_statement());
            done = this.check(TokenType.EOF);
        };
        return prog;
    };
};