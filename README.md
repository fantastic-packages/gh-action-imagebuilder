# OpenWrt GitHub Action ImageBuilder

GitHub CI action to build image via ImageBuilder using official OpenWrt ImageBuilder
Docker containers.

## Example usage

The following YAML code can be used to build image and store created image files
as artifacts.

```yaml
name: Test Build

on:
  workflow_dispatch:
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
          - 23.05.5
          - 24.10.1
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
        shell: bash
        env:
          OP_VERSION: ${{ matrix.release }}
        run: |
          FMTED_VERSION=$([ -z "$OP_VERSION" ] || grep -qiE "^(main|master|snapshots?)$" <<< "$OP_VERSION" || echo "$OP_VERSION")
          echo "Building for $FMTED_VERSION"
          echo "FMTED_VERSION=$FMTED_VERSION" >> $GITHUB_ENV
          BRANCH=$([ -z "$FMTED_VERSION" ] && echo SNAPSHOT || grep -oE '^[0-9]+\.[0-9]+' <<< "$FMTED_VERSION")
          echo "Building for $BRANCH"
          echo "BRANCH=$BRANCH" >> $GITHUB_ENV

      - name: Generate target name
        env:
          TARGET: ${{ matrix.target }}
        run: |
          echo "Target name is $TARGET"
          echo "TARGET=${TARGET/\//-}" >> $GITHUB_ENV

      - name: Add test directories
        run: mkdir artifacts repo

      - name: Build
        uses: fantastic-packages/gh-action-imagebuilder@24.10
        env:
          TARGET: ${{ matrix.target }}
          VERSION: ${{ env.FMTED_VERSION }}
          PROFILE: ${{ matrix.profile }}
          ARTIFACTS_DIR: ${{ github.workspace }}/artifacts
          REPO_DIR: ${{ github.workspace }}/repo
          EXTRA_REPOS: >-
            src/gz|fantastic_packages|https://raw.githubusercontent.com/fantastic-packages/releases/archive/${{ env.BRANCH }}/packages/${{ matrix.arch }}/packages
            src/gz|fantastic_luci|https://raw.githubusercontent.com/fantastic-packages/releases/archive/${{ env.BRANCH }}/packages/${{ matrix.arch }}/luci
            src/gz|fantastic_special|https://raw.githubusercontent.com/fantastic-packages/releases/archive/${{ env.BRANCH }}/packages/${{ matrix.arch }}/special
          NO_LOCAL_REPOS: 1
          KEY_VERIFY: >-
            dW50cnVzdGVkIGNvbW1lbnQ6IFB1YmxpYyB1c2lnbiBrZXkgZm9yIGZhbnRhc3RpYy1wYWNrYWdlcyBidWlsZHMKUldSVC95dG1jaVE5S0ZqSEU4RFE5N3BpWDdvSHZkcjQ5SDNWTGxKRHVKTm11YUtGZ3VPcndYQkcK
          PACKAGES: nano fastfetch
          ROOTFS_SIZE: 256

      - name: Verify images saved
        run: find artifacts/bin/targets/${{ matrix.target }}/ -maxdepth 1 -type f | grep .

      - name: Store images
        uses: actions/upload-artifact@v6
        with:
          name: ${{ matrix.release }}-${{ env.TARGET }}-${{ matrix.profile }}-images
          path: artifacts/bin/targets/${{ matrix.target }}/
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
* `KEY_BUILD_PUB` the paired public key of the above private key.
* `KEY_VERIFY` public keys for `usign` used to verify repos. Format is `'<key1 string>'
  '<key2 string>' '<key3 string>'`. key string must be preprocessed into base64 str
* `NO_DEFAULT_REPOS` disable adding the default ImageBuilder repos
* `NO_LOCAL_REPOS` disable adding the `REPO_DIR` as repo
* `NO_SIGNATURE_CHECK` not check packages signature. If your repos is not
  signed by `usign`, please enable this.
* `DISABLED_SERVICES` which services in `/etc/init.d/` should be disabled
* `PROFILE` override the default target profile. List available via `make info`, Or
  query via `https://downloads.openwrt.org/releases/<version>/targets/<target>/<subtarget>/`
* `PACKAGES` (Optional) specify the list of extra packages (space separated) to be installed.
* `ROOTFS_SIZE` RootFS partition size (MByte)
