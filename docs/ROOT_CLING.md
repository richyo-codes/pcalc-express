# ROOT / Cling Installation

`pcalc express` can use ROOT as an exploratory backend on Linux when `root`
or `cling` is available on `PATH`.

ROOT is the usual installation target. Cling is the C++ interpreter used by
ROOT, and the ROOT docs note that Cling can be used interactively or as part
of ROOT. For this app, install ROOT first unless you specifically want to
build Cling from source.

## Quick check

After installation, verify one of these commands works:

```bash
root
cling
```

For the calculator backend, this should also work:

```bash
root -b -q -l -e 'std::cout << 1 + 1 << std::endl;'
```

## Linux

### Fedora

ROOT is available from Fedora packages:

```bash
sudo dnf install root
```

If you want Python and notebook support too:

```bash
sudo dnf install root python3-root root-notebook
```

### Arch Linux

```bash
sudo pacman -S root
```

### Gentoo

```bash
emerge sci-physics/root
```

### Ubuntu and Debian-based distributions

For Ubuntu and Debian-based systems, use either:

* ROOT precompiled binaries from the official ROOT install page
* Conda

### Snap

```bash
sudo snap install root-framework
```

With the Snap package, ROOT is started directly and you should not source
`thisroot.sh` in the usual way used by tarball installs.

### CVMFS / LCG

If your machine mounts CVMFS, ROOT can be sourced from the LCG release tree.
This is common on CERN-style environments and other managed scientific stacks.

## macOS

### Homebrew

```bash
brew install root
```

### MacPorts

```bash
sudo port install root6
```

### Binary release

ROOT also publishes precompiled macOS binaries. After unpacking, source the
bundle environment script from the `bin/` directory.

## Windows

ROOT publishes Windows binaries and also supports building from source.
After installation, use the Visual Studio Developer Command Prompt or
PowerShell, then source the corresponding environment script:

* `thisroot.bat` from the Developer Command Prompt
* `thisroot.ps1` from PowerShell

## Standalone Cling

If you explicitly want Cling without the rest of ROOT, ROOT’s Cling docs
point to source builds and community-provided distribution options. For this
app, treat standalone Cling as an advanced option; ROOT is the normal path.

## References

* ROOT install guide: https://root.cern/install/
* Cling overview: https://root.cern/cling/
* Cling build instructions: https://root.cern/cling/cling_build_instructions/
* ROOT interactive/built apps guide: https://root.cern/about/interactive_or_built_applications/
