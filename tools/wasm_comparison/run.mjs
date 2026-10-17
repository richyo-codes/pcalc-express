import assert from 'node:assert/strict';
import { readFile, writeFile, mkdir, stat } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { WASI } from 'node:wasi';

const [outputArgument] = process.argv.slice(2);
if (!outputArgument) throw new Error('Usage: node tools/wasm_comparison/run.mjs BUILD_DIRECTORY');
const output = resolve(outputArgument);
for (const backend of ['wasi', 'emscripten']) {
  for (const files of [false, true]) {
    const name = `${backend}-${files ? 'files' : 'numeric'}`;
    const binary = await readFile(join(output, `${name}.wasm`));
    const module = await WebAssembly.compile(binary);
    console.log(JSON.stringify({ name, wasmBytes: binary.length,
      imports: WebAssembly.Module.imports(module).map(i => `${i.module}.${i.name}`),
      ...(backend === 'emscripten' ? { loaderBytes: (await stat(join(output, `${name}.mjs`))).size } : {}),
    }));
    const workspace = join(output, `${name}-workspace`);
    await mkdir(workspace, { recursive: true });
    await writeFile(join(workspace, 'input.bin'), new Uint8Array([0xAA, 0x55, 0x01]));
    await writeFile(join(workspace, 'counter.txt'), '0\n');
    for (let run = 1; run <= (files ? 2 : 1); run++) {
      if (backend === 'wasi') {
        const wasi = new WASI({ version: 'preview1', args: [name], env: {},
          preopens: files ? { '/workspace': workspace } : {}, returnOnExit: true });
        const instance = await WebAssembly.instantiate(module, wasi.getImportObject());
        assert.equal(wasi.start(instance), 0, `${name} run ${run}`);
      } else {
        const { default: createModule } = await import(pathToFileURL(join(output, `${name}.mjs`)));
        const instance = await createModule({ noInitialRun: true });
        if (files) {
          instance.FS.mkdir('/workspace');
          instance.FS.mount(instance.NODEFS, { root: workspace }, '/workspace');
        }
        assert.equal(instance.callMain([]), 0, `${name} run ${run}`);
      }
      if (files) assert.equal((await readFile(join(workspace, 'counter.txt'), 'utf8')).trim(), String(run));
    }
  }
}
console.log('All runtime and file persistence probes passed.');
