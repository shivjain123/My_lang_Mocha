const fs = require('fs');
const strs = [null], arrs = [null];   // handle tables (index = fake "pointer")
let mem;
const cstr = p => {                    // read a C string out of wasm memory
  const b = new Uint8Array(mem.buffer); let e = p;
  while (b[e]) e++;
  return new TextDecoder().decode(b.subarray(p, e));
};
const S = s => strs.push(s) - 1;

const env = {
  mocha_stack_push() {}, mocha_stack_update_line() {}, mocha_stack_pop() {},
  rc_release() {}, mocha_array2d_release() {},
  mocha_str_literal: p => S(cstr(p)),
  mocha_int_to_str:  n => S(String(n)),
  mocha_str_concat:  (a, b) => S(strs[a] + strs[b]),
  mocha_print_str:   (h, nl) => process.stdout.write(strs[h] + (nl ? '\n' : '')),
  mocha_array2d_new: (r, c) => arrs.push({ r, c }) - 1,
  mocha_array2d_rows: h => arrs[h].r,
  mocha_array2d_cols: h => arrs[h].c,
};

WebAssembly.instantiate(fs.readFileSync('alloc_test.wasm'), { env })
  .then(({ instance }) => {
    mem = instance.exports.memory;
    instance.exports.mocha_entry_main();
  });