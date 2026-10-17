// Exercise the exact Dart adapter prelude through the shipped Wasm evaluator.
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const root = new URL('../', import.meta.url);
const source = await readFile(new URL('packages/pcalc_expression_engine/lib/src/endian_helpers.dart', root), 'utf8');
const prelude = source.match(/const endianHelperPrelude = r'''([\s\S]*?)''';/)[1];
const configUrl = new URL('.dart_tool/package_config.json', root);
const config = JSON.parse(await readFile(configUrl, 'utf8'));
const dependency = config.packages.find(p => p.name === 'dart_clang_constexpr');
const packageRoot = new URL(dependency.rootUri, configUrl);
const { initializeDartClangConstexpr } = await import(new URL('lib/dart_clang_constexpr_loader.js', packageRoot));
const engine = await initializeDartClangConstexpr();
const cases = JSON.parse(await readFile(new URL('test/fixtures/endian_cases.json', root), 'utf8'));
let checks = 0;
// ABI IDs from the pinned dependency's evaluator.h.
for (const language of [8, 9, 10]) {
  for (const entry of cases) {
    const result = engine.evaluate(language, `[] {\n${prelude}\nreturn (\n${entry.expression}\n);\n}()`);
    if (entry.error) assert.notEqual(result.status, 0, entry.expression);
    else {
      assert.equal(result.status, 0, `${entry.expression}: ${result.errorMessage}`);
      assert.equal(result.displayText, entry.value, entry.expression);
      assert.equal(result.bitWidth, entry.width, entry.expression);
      assert.equal(Boolean(result.isSigned), false, entry.expression);
    }
    checks++;
  }
}
console.log(`${checks} Wasm endian checks passed`);
