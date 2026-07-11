#!/bin/bash
set -ef
GROUP=
group() {
	endgroup
	echo "::group::  $1"
	GROUP=1
}
endgroup() {
	if [ -n "$GROUP" ]; then
		echo "::endgroup::"
	fi
	GROUP=
}
trap 'endgroup' ERR

group "download setup.sh"
wget -O setup.tar.gz https://codeload.github.com/openwrt/docker/tar.gz/refs/heads/main
tar xf setup.tar.gz --strip=1 --no-same-owner -C .
rm -vrf setup.tar.gz

sed -i 's|/builder/keys/|keys/|g' setup.sh
[ "$CACHE" = "true" ] && sed -i '/wget .*\$file_name/d' setup.sh \
|| sed -i '/wget .*\$file_name/{s|wget -nv|axel -q -H "'"User-Agent: $USER_AGENT"'" -n8|g}' setup.sh

echo -e "\nsetup.sh START"
cat setup.sh
echo -e "setup.sh END\n"
endgroup

group "bash setup.sh"
# snapshot containers don't ship with the ImageBuilder to save bandwidth
# run setup.sh to download and extract the ImageBuilder
bash setup.sh
endgroup

# rules
export BOARD=$(make val.BOARD)
export SUBTARGET=$(make val.SUBTARGET)
export TOPDIR="$(make val.TOPDIR)"
export OUTPUT_DIR="$(make val.OUTPUT_DIR)"
export BIN_DIR="$(make val.BIN_DIR)"
export SCRIPT_DIR="$(make val.SCRIPT_DIR)"
export APK_KEYS="$TOPDIR/keys"
export BUILD_KEY="$(make val.BUILD_KEY)"
export BUILD_KEY_APK_SEC="$(make val.BUILD_KEY_APK_SEC)"
export BUILD_KEY_APK_PUB="$(make val.BUILD_KEY_APK_PUB)"
export STAGING_DIR_HOST="$(make val.STAGING_DIR_HOST)"
PATHBK="$PATH"
export PATH="$STAGING_DIR_HOST/bin:$PATH"

# Initialize bin/ symlink
for d in bin; do
	mkdir -p $artifacts_dir/$d 2>/dev/null
	ln -s $artifacts_dir/$d $d
done

# opkg key-build
if [ -n "$KEY_BUILD" ]; then
	echo "$KEY_BUILD" > $BUILD_KEY
	SIGN_IMG="1"
fi

# apk private-key.pem
if [ -n "$PRIVATE_KEY" ]; then
	echo "$PRIVATE_KEY" > $BUILD_KEY_APK_SEC
	openssl ec -in $BUILD_KEY_APK_SEC -pubout > $BUILD_KEY_APK_PUB
	ADD_LOCAL_KEY="1"
fi
if [ -n "$PUBLIC_KEY_VERIFY" ]; then
	for _key in $PUBLIC_KEY_VERIFY; do
		base64 -d <<< "$_key" > /tmp/_key
		cp -f /tmp/_key $APK_KEYS/$(md5sum /tmp/_key | awk '{print $1}').pem
	done
fi

group "ls -R $APK_KEYS"
ls -R $APK_KEYS
endgroup

n=$(sed -n '$=' repositories)
if [ -n "$NO_DEFAULT_REPOS" ]; then
	sed -i 's|^http|# http|' repositories
fi
if [ -z "$NO_LOCAL_REPOS" ]; then
	sed -i "${n}a\\file://$REPO_DIR/packages.adb" repositories
fi
for EXTRA_REPO in $EXTRA_REPOS; do
	sed -i "${n}a\\$EXTRA_REPO" repositories
done

group "repositories"
cat repositories
endgroup

if [ -n "$ROOTFS_SIZE" ]; then
	sed -i "s|\(\bCONFIG_TARGET_ROOTFS_PARTSIZE\)=.*|\1=$ROOTFS_SIZE|" .config
fi

RET=0

export PATH="$PATHBK"

group "make image"
make image \
	PROFILE="$PROFILE" \
	DISABLED_SERVICES="$DISABLED_SERVICES" \
	ADD_LOCAL_KEY="$ADD_LOCAL_KEY" \
	PACKAGES="$PACKAGES" || RET=$?
endgroup

if [ "$SIGN_IMG" = '1' -a -n "$KEY_BUILD" ];then
	pushd $BIN_DIR
	$STAGING_DIR_HOST/bin/usign -S -m sha256sums -s $BUILD_KEY
	popd
fi

exit "$RET"
