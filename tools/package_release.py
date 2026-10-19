#!/usr/bin/env python3
"""Package release assets on their build host, preserving Unix metadata."""

import argparse
import os
from pathlib import Path
import re
import shutil
import tarfile


def package(platform, tag, output):
    if not re.fullmatch(r"v[0-9][A-Za-z0-9.+-]*", tag):
        raise ValueError(f"Unsupported release tag: {tag!r}")
    output.mkdir(parents=True, exist_ok=True)
    prefix = f"pcalc-express-{tag}"

    def archive(source, label, zip_format=False):
        source = Path(source)
        if not source.is_dir() or not any(source.iterdir()):
            raise FileNotFoundError(f"Missing or empty bundle: {source}")
        name = output / f"{prefix}-{label}"
        if zip_format:
            shutil.make_archive(str(name), "zip", source)
        else:
            with tarfile.open(f"{name}.tar.gz", "w:gz") as bundle:
                bundle.add(source, arcname=source.name)

    def copy_one(pattern, label, extension):
        matches = list(Path('.').glob(pattern))
        if len(matches) != 1:
            raise ValueError(f"Expected one {pattern}, found {len(matches)}")
        shutil.copy2(matches[0], output / f"{prefix}-{label}.{extension}")

    if platform == "android":
        copy_one("build/app/outputs/flutter-apk/app-release.apk", "android-universal", "apk")
    elif platform in ("linux", "linux_gtk4"):
        variant = "gtk4" if platform == "linux_gtk4" else "gtk3"
        build = "build/linux-gtk4" if variant == "gtk4" else "build/linux"
        archive(f"{build}/x64/release/bundle", f"linux-x64-{variant}")
        for extension in ("deb", "rpm"):
            copy_one(f"{build}/packages/{extension}/*.{extension}", f"linux-x64-{variant}", extension)
        if variant == "gtk4":
            source = Path(os.environ["RUNNER_TEMP"]) / "pcalc-express-flatpak-gtk4/ca.richyoung.pcalcexpress.gtk4.flatpak"
            shutil.copy2(source, output / f"{prefix}-linux-x64-gtk4.flatpak")
    elif platform == "flatpak":
        source = Path(os.environ["RUNNER_TEMP"]) / "pcalc-express-flatpak/ca.richyoung.pcalcexpress.flatpak"
        shutil.copy2(source, output / f"{prefix}-linux-x64-gtk3.flatpak")
    elif platform == "windows":
        archive("build/windows/x64/runner/Release", "windows-x64", zip_format=True)
    elif platform == "macos":
        # Flutter's macOS release app contains the supported target slices.
        archive("build/macos/Build/Products/Release/pcalc_express.app", "macos")
    elif platform == "web":
        archive("build/web", "web-wasm", zip_format=True)
    else:
        raise ValueError(f"Unknown platform: {platform}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("platform")
    parser.add_argument("tag")
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    package(args.platform, args.tag, args.output)
