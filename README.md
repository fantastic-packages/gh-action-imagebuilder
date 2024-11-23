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
    name: ${{ matrix.target[0] }}-${{ matrix.target[1] }} build
    runs-on: ubuntu-latest
    strategy:
      matrix:
        version: [21.02.5, 22.03.5]
        arch:
          - x86_64
          - mips_24kc
        include:
          - arch: x86_64
            target: ['x86', '64']
          - arch: mips_24kc
            target: ['ath79', 'nand']
            profile: netgear_wndr4300

    steps:
      - uses: actions/checkout@v2
        with:
          fetch-depth: 0

      - name: Determine branch name
        env:
          VERSION: ${{ matrix.version }}
        run: |
          echo "VERSION=$VERSION" >> $GITHUB_ENV
          BRANCH="${VERSION%.*}"
          echo "Building for $BRANCH"
          echo "BRANCH=$BRANCH" >> $GITHUB_ENV

      - name: Generate full target name
        env:
          TARGET: ${{ format('{0}-{1}', matrix.target[0], matrix.target[1]) }}
        run: |
          echo "Full target name is $TARGET"
          echo "TARGET=$TARGET" >> $GITHUB_ENV

      - name: Build
        uses: muink/gh-action-imagebuilder@master
        env:
          ARCH: ${{ env.TARGET }}-${{ env.VERSION }}
          PROFILE: ${{ matrix.profile}}
          REPO_DIR: ${{ github.workspace }}/releases/packages-${{ env.BRANCH }}/${{ matrix.arch }}/luci
          PACKAGES: bash natmapt

      - name: Store images
        uses: actions/upload-artifact@v2
        with:
          name: ${{ env.TARGET }}-${{ matrix.profile }}-images
          path: bin/targets/${{ matrix.target[0] }}/${{ matrix.target[1] }}/
```

## Environmental variables

The action reads a few env variables:

* `ARCH` determines the used OpenWrt ImageBuilder Docker container.
  E.g. `x86-64` or `x86-64-22.03.2`.
* `ARTIFACTS_DIR` determines where built images are saved.
  Defaults to the default working directory (`GITHUB_WORKSPACE`).
* `CONTAINER` can set other ImageBuilder containers than `openwrt/imagebuilder`.
* `EXTRA_REPOS` are added to the `repositories.conf`, where `|` are replaced by white
  spaces.
* `NO_DEFAULT_REPOS` disable adding the default ImageBuilder repos
* `NO_LOCAL_REPOS` disable adding the default working directory as repo
* `REPO_DIR` used to add current repo to `repositories.conf`. Defaults to
  the default working directory (`GITHUB_WORKSPACE`).
* `KEY_BUILD` (Only for ipk) can be a private Signify/`usign` key to sign the images.
* `KEY_BUILD_PUB` (Only for ipk)  the paired public key of the above private key.
* `KEY_VERIFY` public keys for `usign` used to verify repos. Format is `'<key1 string>'
  '<key2 string>' '<key3 string>'`. key string must be preprocessed into base64 str
* `PRIVATE_KEY` can be a private key to sign the packages (apk) feed.
* `PUBLIC_KEY_VERIFY` public keys for `apk` used to verify repos. Format is `'<key1 string>'
  '<key2 string>' '<key3 string>'`. key string must be preprocessed into base64 str
* `NO_SIGNATURE_CHECK` not check packages signature. If your repos is not
  signed by `usign`, please enable this.
* `DISABLED_SERVICES` which services in `/etc/init.d/` should be disabled
* `PROFILE` override the default target profile. List available via `make info`, Or
  query via `https://downloads.openwrt.org/releases/<version>/targets/<target>/<subtarget>/`
* `PACKAGES` (Optional) specify the list of extra packages (space separated) to be installed.
* `ROOTFS_SIZE` RootFS partition size (MByte)
