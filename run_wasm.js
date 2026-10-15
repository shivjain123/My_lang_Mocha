// usage: node run_wasm.js <file.wasm> [exported function, default mocha_entry_main]
const fs = require('fs');
const { WASI } = require('node:wasi');
const wasi = new WASI({ version: 'preview1' });
const [file, fn = 'mocha_entry_main'] = process.argv.slice(2);
WebAssembly.instantiate(fs.readFileSync(file), wasi.getImportObject()).then(({ instance }) => {
  wasi.initialize(instance);
  instance.exports[fn]();
});