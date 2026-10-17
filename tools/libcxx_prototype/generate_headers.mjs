// Build an in-memory header bundle from an explicitly selected Emscripten SDK.
// Generated output stays in the prototype build directory, not in the app.
import { readdir, readFile, writeFile } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { createHash } from 'node:crypto';

const [sdkArgument, output] = process.argv.slice(2);
if (!sdkArgument || !output) throw new Error('Usage: generate_headers.mjs EMSDK_ROOT OUTPUT.inc');
const sdk = resolve(sdkArgument);
const versions = await readdir(join(sdk, 'upstream/lib/clang'));
if (versions.length !== 1) throw new Error('Expected one Clang resource directory');
const roots = [
  [join(sdk, 'upstream/emscripten/cache/sysroot/include'), '/pcalc/sysroot/include'],
  [join(sdk, 'upstream/lib/clang', versions[0], 'include'), '/pcalc/resource/include'],
];
const entries = [];
async function walk(directory, virtualDirectory) {
  for (const entry of (await readdir(directory, { withFileTypes: true })).sort((a, b) => a.name.localeCompare(b.name, 'en'))) {
    const path = join(directory, entry.name);
    const virtualPath = `${virtualDirectory}/${entry.name}`;
    if (entry.isDirectory()) await walk(path, virtualPath);
    else if (entry.isFile()) {
      const content = await readFile(path, 'utf8');
      if (content.includes(')pcalc_header"')) throw new Error(`Raw string delimiter collision: ${path}`);
      entries.push(`{${JSON.stringify(virtualPath)}, R"pcalc_header(${content})pcalc_header"}`);
    } else throw new Error(`Unsupported bundle entry: ${path}`);
  }
}
for (const [directory, virtualDirectory] of roots) await walk(directory, virtualDirectory);
const source = '// Generated from SDK headers; retain the SDK licenses when distributing.\n' +
  'struct PcalcBundledHeader { const char* path; const char* content; };\n' +
  `static const PcalcBundledHeader kPcalcBundledHeaders[] = {\n${entries.join(',\n')}\n};\n`;
await writeFile(output, source);
console.log(JSON.stringify({ headers: entries.length, bytes: Buffer.byteLength(source), sha256: createHash('sha256').update(source).digest('hex') }));
