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

## Credits

- https://github.com/Blake-Madden/tinyexpr-plusplus
- https://github.com/codeplea/tinyexpr
- https://www.analogx.com/contents/download/programming/pcalc/freeware.htm
