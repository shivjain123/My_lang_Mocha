import sys
sys.path.insert(0, "..")
from mocha_emitter import parse_module, parse_globals, emit_function, infer_returns

text = open(sys.argv[1] + ".ll", encoding="utf-8").read()
funcs, g = parse_module(text), parse_globals(text)
infer_returns(funcs, g)
try:
    emit_function(funcs[sys.argv[2]], g)
    print("emitted fine")
except Exception as e:
    print(e)