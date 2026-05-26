# test_repl_feasibility.py
import sys
sys.path.append(r'C:\Users\shiv jain\Coding_Projects\My_Codes\Mocha\Python_AND_ExecutableFiles')

from mocha_lexer import Lexer
from mocha_parser import Parser

# test 1 — single expression
test1 = "2 + 3;"
try:
    tokens = Lexer(test1).tokenise()
    ast = Parser(tokens).parse()
    print("test1 passed:", ast)
except Exception as e:
    print("test1 failed:", e)

# test 2 — var declaration
test2 = "var x: int = 5;"
try:
    tokens = Lexer(test2).tokenise()
    ast = Parser(tokens).parse()
    print("test2 passed:", ast)
except Exception as e:
    print("test2 failed:", e)

# test 3 — print statement
test3 = 'print("hello", newLine=true);'
try:
    tokens = Lexer(test3).tokenise()
    ast = Parser(tokens).parse()
    print("test3 passed:", ast)
except Exception as e:
    print("test3 failed:", e)

# test 4 — if block
test4 = "if (x > 3) { print(x); };"
try:
    tokens = Lexer(test4).tokenise()
    ast = Parser(tokens).parse()
    print("test4 passed:", ast)
except Exception as e:
    print("test4 failed:", e)