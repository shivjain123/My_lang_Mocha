import sys
sys.path.insert(0, "..")
from mocha_emitter import parse_module, parse_globals, emit_function, infer_returns

text = open("comprehensive_v0.5_tests.ll", encoding="utf-8").read()
funcs, g = parse_module(text), parse_globals(text)
infer_returns(funcs, g)
for name in ("mocha_lambda_656", "mocha_lambda_1246"):
    try:
        for n, s in emit_function(funcs[name], g):
            print(name, n, s)
    except Exception as e:
        print(name, "ERR", type(e).__name__, e)