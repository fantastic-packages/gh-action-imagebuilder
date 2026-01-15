# OpenWrt GitHub Action ImageBuilder

GitHub CI action to build image via ImageBuilder using official OpenWrt ImageBuilder
Docker containers.

## Example usage

The following YAML code can be used to build image and store created image files
as artifacts.

```yaml
name: Test Build

on:
  pull_request:
    branches:
      - main

jobs:
  build:
    name: ${{ matrix.release }} ${{ matrix.target }} build
    runs-on: ubuntu-latest
    strategy:
      matrix:
        release:
          - master
          - 25.12.0-rc2
        arch:
          - mips_24kc
          - x86_64
        include:
          - arch: mips_24kc
            target: ath79/nand
            profile: netgear_wndr4300
          - arch: x86_64
            target: x86/64
            profile: generic

    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0

      - name: Determine branch name
        env:
          VERSION: ${{ matrix.release }}
        run: |
          echo "VERSION=$VERSION" >> $GITHUB_ENV
          BRANCH="${VERSION%.*}"
          echo "Building for $BRANCH"
          echo "BRANCH=$BRANCH" >> $GITHUB_ENV

      - name: Generate target name
        env:
          TARGET: ${{ matrix.target }}
        run: |
          echo "Target name is $TARGET"
          echo "TARGET=${TARGET/\//-}" >> $GITHUB_ENV

      - name: Build
        uses: fantastic-packages/gh-action-imagebuilder@master
        with:
          cache: false # enable caching for downloaded imagebuilder/sdk, you needs to create an empty `openwrt.org-cache` repository
          token: ${{ secrets.NEW_PERSONAL_ACCESS_TOKEN }} # only required when `cache` is enabled, used to push content to the `openwrt.org-cache` repository
        env:
          TARGET: ${{ matrix.target }}
          VERSION: ${{ matrix.release }}
          PROFILE: ${{ matrix.profile}}
          REPO_DIR: ${{ github.workspace }}/releases/packages-${{ env.BRANCH }}/${{ matrix.arch }}/luci
          PACKAGES: bash natmapt

      - name: Store images
        uses: actions/upload-artifact@v6
        with:
          name: ${{ matrix.release }}-${{ env.TARGET }}-${{ matrix.profile }}-images
          path: bin/targets/${{ matrix.target }}/
```

## Environmental variables

The action reads a few env variables:

* `FILE_HOST` determines the used OpenWrt download server.
  E.g. `https://downloads.openwrt.org` or `https://mirrors.cicku.me/openwrt`.
* `TARGET` determines the used OpenWrt ImageBuilder target.
  E.g. `x86/64` or `ath79/generic`.
* `VERSION` determines the used OpenWrt ImageBuilder version.
  E.g. `24.10.5` or `24.10-SNAPSHOT` or `snapshots`.
* `ARTIFACTS_DIR` determines where built images are saved.
  Defaults to the default working directory (`GITHUB_WORKSPACE`).
* `EXTRA_REPOS` are added to the `repositories.conf`, where `|` are replaced by white
  spaces.
* `REPO_DIR` used to add current repo to `repositories.conf`. Defaults to
  the default working directory (`GITHUB_WORKSPACE`).
* `KEY_BUILD` can be a private Signify/`usign` key to sign the images.
<!-- * `PRIVATE_KEY` can be a private key to sign the packages (apk) feed. -->
* `PUBLIC_KEY_VERIFY` public keys for `apk` used to verify repos. Format is `'<key1 string>'
  '<key2 string>' '<key3 string>'`. key string must be preprocessed into base64 str
* `NO_DEFAULT_REPOS` disable adding the default ImageBuilder repos
* `NO_LOCAL_REPOS` disable adding the `REPO_DIR` as repo
* `DISABLED_SERVICES` which services in `/etc/init.d/` should be disabled
* `PROFILE` override the default target profile. List available via `make info`, Or
  query via `https://downloads.openwrt.org/releases/<version>/targets/<target>/<subtarget>/`
* `PACKAGES` (Optional) specify the list of extra packages (space separated) to be installed.
* `ROOTFS_SIZE` RootFS partition size (MByte)
