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

group "bash setup.sh"
# snapshot containers don't ship with the ImageBuilder to save bandwidth
# run setup.sh to download and extract the ImageBuilder
[ ! -f setup.sh ] || bash setup.sh
endgroup

# rules
eval "$(grep CONFIG_TARGET_BOARD .config)"
eval "$(grep CONFIG_TARGET_SUBTARGET .config)"
[ -z "$(grep CONFIG_USE_APK .config)" ] || export USE_APK=y
export BOARD=$CONFIG_TARGET_BOARD
export SUBTARGET=$CONFIG_TARGET_SUBTARGET
export TOPDIR=$(pwd)
export OUTPUT_DIR=$TOPDIR/bin
export BIN_DIR=$OUTPUT_DIR/targets/$BOARD/$SUBTARGET
export SCRIPT_DIR=$TOPDIR/scripts
export OPKG_KEYS=$TOPDIR/keys
export BUILD_KEY=$TOPDIR/key-build
export BUILD_KEY_APK_SEC=$TOPDIR/keys/local-private-key.pem
export BUILD_KEY_APK_PUB=$TOPDIR/keys/local-public-key.pem
export STAGING_DIR_HOST=$TOPDIR/staging_dir/host
PATHBK="$PATH"
export PATH="$STAGING_DIR_HOST/bin:$PATH"

for d in bin; do
	mkdir -p /artifacts/$d 2>/dev/null
	ln -s /artifacts/$d $d
done

if [ -n "$KEY_BUILD" ]; then
	echo "$KEY_BUILD" > $BUILD_KEY
	SIGN="1"
fi
if [ -n "$KEY_BUILD_PUB" ]; then
	echo "$KEY_BUILD_PUB" > $BUILD_KEY.pub
	$SCRIPT_DIR/opkg-key add $BUILD_KEY.pub
	ADD_LOCAL_KEY="1"
fi
if [ -n "$KEY_VERIFY" ]; then
	for _key in $KEY_VERIFY; do
		base64 -d <<< "$_key" > /tmp/_key
		$SCRIPT_DIR/opkg-key add /tmp/_key
	done
fi

if [ -n "$PRIVATE_KEY" ]; then
	echo "$PRIVATE_KEY" > $BUILD_KEY_APK_SEC
	openssl ec -in $BUILD_KEY_APK_SEC -pubout > $BUILD_KEY_APK_PUB
	ADD_LOCAL_KEY="1"
	SIGN="1"
fi
if [ -n "$PUBLIC_KEY_VERIFY" ]; then
	for _key in $PUBLIC_KEY_VERIFY; do
		base64 -d <<< "$_key" > /tmp/_key
		cp -f /tmp/_key $OPKG_KEYS/$(md5sum /tmp/_key | awk '{print $1}').pem
	done
fi

group "ls -R $OPKG_KEYS"
ls -R $OPKG_KEYS
endgroup

if [ -n "$USE_APK" ]; then

n=$(sed -n '$=' repositories)

if [ -n "$NO_DEFAULT_REPOS" ]; then
	sed -i 's|^http|# http|g' repositories
fi
if [ -z "$NO_LOCAL_REPOS" ]; then
	sed -i "${n}a\\file:///repo/packages.adb" repositories
fi
for EXTRA_REPO in $EXTRA_REPOS; do
	sed -i "${n}a\\$EXTRA_REPO" repositories
done
group "repositories"
cat repositories
endgroup

else # use opkg

regexp='src imagebuilder file:packages'

if [ -n "$NO_DEFAULT_REPOS" ]; then
	sed -i 's|^src/gz|## src/gz|g' repositories.conf
fi
if [ -z "$NO_LOCAL_REPOS" ]; then
	sed -i "/$regexp/i\\src custom file:///repo/" repositories.conf
fi
for EXTRA_REPO in $EXTRA_REPOS; do
	sed -i "/$regexp/i\\$(tr '|' ' ' <<< "$EXTRA_REPO")" repositories.conf
done
if [ -n "$NO_SIGNATURE_CHECK" ]; then
	sed -i 's|^option check_signature|## option check_signature|' repositories.conf
fi

group "repositories.conf"
cat repositories.conf
endgroup

fi

if [ -n "$ROOTFS_SIZE" ]; then
	sed -i "s|\(\bCONFIG_TARGET_ROOTFS_PARTSIZE\)=.*|\1=$ROOTFS_SIZE|" .config
fi

RET=0

export PATH="$PATHBK"
make image \
	PROFILE="$PROFILE" \
	DISABLED_SERVICES="$DISABLED_SERVICES" \
	ADD_LOCAL_KEY="$ADD_LOCAL_KEY" \
	PACKAGES="$PACKAGES" || RET=$?

if [ "$SIGN" = '1' ];then
	pushd $BIN_DIR
	if [ -z "$USE_APK" ]; then
	$STAGING_DIR_HOST/bin/usign -S -m sha256sums -s $BUILD_KEY
	fi
	popd
fi

exit "$RET"
