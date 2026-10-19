# Tagged releases

Push a version tag such as `v1.2.3` to run all platform builds and publish a
GitHub Release with generated release notes. Tags containing a hyphen, such as
`v1.2.3-rc.1`, publish as prereleases.

```sh
git tag -a v1.2.3 -m 'pcalc express v1.2.3'
git push origin v1.2.3
```

The build workflow calls the separate release workflow after every platform job
succeeds. It attaches the Android APK, Linux GTK3 and GTK4 bundles, DEB and RPM
packages, both Flatpaks, Windows ZIP, macOS app archive, WebAssembly web ZIP, and
`SHA256SUMS`. Unix bundles are archived on the build host to preserve executable
permissions and symlinks. The macOS archive retains its `.app` directory.

All asset filenames use the triggering tag. These are the existing release-mode
builds; this workflow does not add signing or notarization. The web ZIP must be
served over HTTP; GitHub Pages deployment remains a separate workflow.

A failed build prevents publishing. Fix the build and rerun the tag workflow
(or dispatch the build workflow against the tag). Uploads happen to a draft,
which is published only after they succeed. Reruns can complete a draft; an
already published release is left unchanged. CI artifacts still expire after
seven days; published release assets are retained with the release.

The workflow uses the repository's `GITHUB_TOKEN` with `contents: write`; no
additional release token is required.
