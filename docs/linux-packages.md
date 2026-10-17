# Debian and RPM packages

CI produces native packages for both Linux runners:

- `pcalc-express`: standard Flutter GTK3 build;
- `pcalc-express-gtk4`: custom Flutter GTK4 build.

The variants install the same application ID and desktop entry, so their
packages conflict. Installing one replaces the other rather than creating two
indistinguishable launchers.

Each package installs the Flutter bundle under `/usr/lib/pcalc-express`, the
`pcalc-express` command under `/usr/bin`, and desktop, icon, AppStream, and
license files under `/usr/share`. The package build replaces Flutter plugin
build-tree RUNPATHs with paths relative to the installed private bundle.

## Build locally

Install CMake, CPack, `dpkg-deb`, `rpmbuild`, and `patchelf`, then build the
desired Flutter bundle before invoking the package script.

GTK3:

```sh
flutter build linux --release
tools/build_linux_packages.sh build/linux/packages "$(git describe --tags --always)" gtk3
```

GTK4, after configuring the custom Flutter SDK described in
[Linux GTK3 / GTK4 runners](linux-gtk.md):

```sh
bash tool/flutter_linux.sh gtk4 build --release
PCALC_LINUX_BUNDLE="$PWD/build/linux-gtk4/x64/release/bundle" \
  tools/build_linux_packages.sh build/linux-gtk4/packages \
  "$(git describe --tags --always)" gtk4
```

DEB files and checksums are written below `deb/`; RPM files and checksums are
written below `rpm/`. Git descriptions such as `v1.2.3-4-gabc123` become package
version `1.2.3-4.gabc123`.

Install with the distribution package manager so runtime dependencies are
resolved:

```sh
sudo apt install ./pcalc-express_*.deb
sudo dnf install ./pcalc-express-*.rpm
```

The current native evaluator links LLVM and Clang 22, so the target repository
must provide compatible `libLLVM` and `libclang-cpp` runtime packages.
