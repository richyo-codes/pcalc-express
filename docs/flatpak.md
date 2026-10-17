# Flatpak builds

The GTK3 Flatpak uses the Freedesktop 25.08 runtime. The GTK4 variant uses
GNOME 51, which provides GTK4, and ships on the `gtk4` Flatpak branch. Both
variants retain the application ID `ca.richyoung.pcalcexpress`.

## Build GTK4

Install `flatpak`, `flatpak-builder`, and `patchelf`, then install the runtime
and SDK:

```sh
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install --user flathub org.gnome.Platform//51 org.gnome.Sdk//51
```

Configure the matching custom SDK and prebuilt engine as described in
[Linux GTK3 / GTK4 runners](linux-gtk.md), then run:

```sh
bash tools/build_flatpak_gtk4.sh
```

To package a previously built release bundle:

```sh
bash tools/build_flatpak_gtk4.sh \
  --bundle-dir build/linux-gtk4/x64/release/bundle \
  --out-dir build/linux-gtk4/flatpak-output
```

The builder stages a copy, removes build-machine library search paths, and
copies dependencies missing from GNOME's runtime, including LLVM and Clang.
It checks every bundled shared library inside that runtime before export.
If the host build needs newer library symbol versions than the runtime,
rebuild the app against a compatible toolchain; do not bypass that check.
CI reuses the GTK4 release bundle and uploads a separately named artifact.

## Install and launch

```sh
flatpak install --user --reinstall build/linux-gtk4/flatpak-output/ca.richyoung.pcalcexpress.gtk4.flatpak
flatpak run ca.richyoung.pcalcexpress//gtk4
```

GTK3 and GTK4 can be installed on separate Flatpak branches. Specify `//gtk4`
when launching to select that branch explicitly.
