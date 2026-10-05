const fs = require('fs');
const { WASI } = require('node:wasi');
const wasi = new WASI({ version: 'preview1' });

WebAssembly.instantiate(fs.readFileSync('alloc_full.wasm'), wasi.getImportObject())
  .then(({ instance }) => {
    wasi.initialize(instance);
    instance.exports.mocha_entry_main();
  });