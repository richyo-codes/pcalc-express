# Flatpak Build & Run

## App ID

- `com.rnd.pcalc_ng`

## Files

- Manifest: `flatpak/com.rnd.pcalc_ng.yml`
- Desktop entry: `flatpak/com.rnd.pcalc_ng.desktop`
- Metainfo: `flatpak/com.rnd.pcalc_ng.metainfo.xml`
- Host build script: `tools/build_flatpak.sh`
- Container build script: `tools/build_flatpak_container.sh`

## Build on host

```bash
cd /home/ry/code_flutter/rnd_pcalc_ng_public
./tools/build_flatpak.sh
```

The script:

1. Builds Flutter Linux release bundle
2. Runs `flatpak-builder`
3. Creates bundle at `build/com.rnd.pcalc_ng.flatpak`

## Build in container

```bash
cd /home/ry/code_flutter/rnd_pcalc_ng_public
flutter build linux --release
./tools/build_flatpak_container.sh
```

Container build uses `ghcr.io/flathub-infra/flatpak-builder-lint:latest` with
Podman or Docker.

## Install & run

```bash
flatpak install --user --reinstall ./build/com.rnd.pcalc_ng.flatpak
flatpak run com.rnd.pcalc_ng
```

## Notes

- The manifest packages the existing Flutter Linux release bundle rather than
  rebuilding inside the Flatpak manifest.
- The host script uses `flatpak-builder --disable-rofiles-fuse` to avoid FUSE
  issues commonly seen in CI.
- In CI, the host script attempts `--disable-sandbox` when supported. If the
  installed `flatpak-builder` is older and Podman or Docker is available, it
  falls back to the container build script.
