# PCalc Express

This is a programming calculator partially inspired by AnalogX PCalc.

The primary goal is to allow using C like math and logic expressions at parity with AnalogX PCalc.  
Unlike PCalc which is Windows Only, leveraging Flutter this app will run on Windows, Linux, Mac, Android and iOS.
Eventually I might add additional features.  Right now it is mostly a fun project to play with Flutter and C++ interop.

## Math Expression Parser

This application is currently using https://github.com/Blake-Madden/tinyexpr-plusplus for the primary mathematical expression parser and evaluator.

Other backends or implementations are currently being investigated.

## Features missing when compared to AnalogX PCalc
 - type casting
 - no bitshifting floats
 - binary literals
 - char literals
 - will list more when i have a test suite

## Flutter Native Assets

This app also serves as a demonstration of the usage of Flutter Native Assets and build hooks.  

This allows the build system to automatically build and bundle the C++ dependency, rather than having to build it seperately and commit binary blobs to this repository.

## Debug Native Asset Build

`dart run hook/build.dart`

## Flatpak

Flatpak packaging files live under `flatpak/`.

- Host build: `./tools/build_flatpak.sh`
- Container build: `./tools/build_flatpak_container.sh`

See `docs/FLATPAK.md` for details.

## WebAssembly

To build and run the app without running tests:

```bash
./tools/run_wasm.sh
```

Open `http://127.0.0.1:8080` and press `Ctrl+C` to stop the server. Use
`--port 9000` to choose another port.

Build and run the web test suite with the Dart-to-Wasm target:

```bash
./tools/build_test_wasm.sh
```

The script enables Flutter web support, fetches dependencies, runs tests in
Chrome with `--wasm`, writes the release build to `build/web/`, then serves it
at `http://127.0.0.1:8080`. Press `Ctrl+C` to stop the server. Use
`--no-serve` for a build/test-only run, or `--port 9000` to choose a port.

To make a human-readable phone screenshot using Chromium's real font
rendering, run:

```bash
./tools/capture_web_screenshot.sh
```

It builds the Wasm release and writes
`test/screenshots/calculator_phone_light.png` and
`test/screenshots/calculator_phone_dark.png`. This is separate from the
widget-test goldens, which intentionally use Flutter's block-shaped test font
for deterministic layout checks. It requires Chromium and Node.js. Use
`--theme light` or `--theme dark` to capture one palette, `--output PATH` to
choose its destination, or `--port` to choose the temporary server port. Use
`--no-build` to capture an already-built `build/web/` directory.

## GitHub Pages

The `Deploy WebAssembly to GitHub Pages` workflow publishes the Wasm build
from the `main` or `publish` branch. Enable GitHub Pages for the repository
with **Source: GitHub Actions** under Settings → Pages; subsequent pushes
will deploy the calculator at the repository's Pages URL.

## Credits

- https://github.com/Blake-Madden/tinyexpr-plusplus
- https://github.com/codeplea/tinyexpr
- https://www.analogx.com/contents/download/programming/pcalc/freeware.htm

## License

pcalc express is licensed under the GNU General Public License, version 3 only
(`GPL-3.0-only`). Third-party dependencies retain their respective licenses.
