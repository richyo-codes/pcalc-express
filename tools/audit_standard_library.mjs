// Run after `flutter pub get`. Audits the pinned evaluator's shipped Wasm.
import { readFile } from 'node:fs/promises';

const root = new URL('../', import.meta.url);
const configUri = new URL('.dart_tool/package_config.json', root);
const config = JSON.parse(await readFile(configUri, 'utf8'));
const dependency = config.packages.find(p => p.name === 'dart_clang_constexpr');
if (!dependency) throw new Error('Run flutter pub get before auditing.');
const packageRoot = new URL(dependency.rootUri, configUri);
const { initializeDartClangConstexpr } = await import(
  new URL('lib/dart_clang_constexpr_loader.js', packageRoot).href
);
const engine = await initializeDartClangConstexpr();
// The package's C ABI assigns C++20 language ID 1.
const cases = [
  ['abs(-42)', '42'],
  ['ceil(4.2)', '5'],
  ['floor(4.8)', '4'],
  ['trunc(-4.8)', '-4'],
  ['round(4.5)', '5'],
  ['sqrt(81.0)', '9'],
  ['pow(2, 10)', '1024'],
  ['pow(9.0, 0.5)', '3'],
  ['sin(0.0)', '0'],
  ['cos(0.0)', '1'],
  ['tan(0.0)', '0'],
  ['fmin(4.0, 2.0)', '2'],
  ['fmax(4.0, 2.0)', '4'],
  ['std::min(9, 3)', '3'],
  ['std::max(9, 3)', '9'],
  ['std::clamp(99, 0, 10)', '10'],
  ['std::numeric_limits<int>::max()', '2147483647'],
  ['std::numeric_limits<double>::epsilon() > 0', 'true'],
  ['std::popcount(0xF0u)', '4'],
  ['std::countl_zero(1u)', '31'],
  ['std::countr_zero(8u)', '3'],
  ['std::rotl(1u, 3)', '8'],
  ['std::rotr(8u, 3)', '1'],
  ['std::bit_width(255u)', '8'],
  ['std::gcd(12, 18)', '6'],
  ['std::lcm(12, 18)', '36'],
  ['std::midpoint(2, 10)', '6'],
  ['log(1.0)', '0'],
  ['exp(0.0)', '1'],
  ['fabs(-2.0)', '2'],
  ['fmod(7.0, 3.0)', '1'],
  ['strlen("abc")', '3'],
  ['strcmp("a", "a")', '0'],
  ['atoi("42")', '42'],
  ['isdigit(\'4\') != 0', 'true'],
  ['[] { std::array<int, 3> a{3, 1, 2}; std::sort(a.begin(), a.end()); return a[0]; }()', '1'],
  ['[] { int a[]{1, 2, 3}; return std::accumulate(a, a + 3, 0); }()', '6'],
];
console.log('| C++20 expression | Wasm probe |');
console.log('| --- | --- |');
for (const [expression, expected] of cases) {
  const result = engine.evaluate(1, expression);
  const status = result.status !== 0 ? 'Rejected' :
    result.displayText === expected ? 'Pass' : `Unexpected: ${result.displayText}`;
  console.log(`| \`${expression}\` | ${status} |`);
}
