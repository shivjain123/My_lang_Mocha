import sys
sys.path.insert(0, "..")
from mocha_emitter import parse_module, parse_globals, infer_returns, infer_collections, MODULE_FUNCS

text = open("test_ih.ll", encoding="utf-8").read()
funcs, g = parse_module(text), parse_globals(text)
infer_returns(funcs, g)
print(infer_collections(funcs["snap"]))