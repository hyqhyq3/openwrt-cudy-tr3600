#!/bin/bash
# OpenWrt build for Cudy TR3600 v1: openwrt-25.12 + PR#24596 + real-hw fixes
# Works on Debian 12 (also in Docker: docker run -v $PWD:/build -w /build debian:12 bash build.sh)
set -e
export DEBIAN_FRONTEND=noninteractive
export FORCE_UNSAFE_CONFIGURE=1   # required when building as root (tools/tar)
# Optional proxy for restricted networks:
# export http_proxy=http://your-proxy:7890 https_proxy=http://your-proxy:7890

log() { echo "[$(date '+%m-%d %H:%M:%S')] $*"; }

log "step 1/6: install build deps (Debian 12)"
apt-get update
apt-get install -y build-essential flex bison gawk gettext git libncurses-dev \
  libssl-dev rsync unzip zlib1g-dev file wget xz-utils libelf-dev \
  python3-distutils python3-setuptools swig curl ca-certificates

REPO_DIR=${REPO_DIR:-$PWD/openwrt}
if [ ! -d "$REPO_DIR/.git" ]; then
  log "step 2/6: clone openwrt-25.12"
  git clone --depth 1 -b openwrt-25.12 https://github.com/openwrt/openwrt.git "$REPO_DIR"
fi
cd "$REPO_DIR"
git fetch origin pull/24596/head
git checkout -f FETCH_HEAD
log "PR head: $(git rev-parse --short HEAD)"

log "step 3/6: apply TR3600 fixes"
if [ -f /build/cudy-tr3600-v1-fixes.patch ]; then
  git apply /build/cudy-tr3600-v1-fixes.patch
else
  git apply "$OLDPWD/cudy-tr3600-v1-fixes.patch"
fi

log "step 4/6: feeds"
scripts/feeds update -a
scripts/feeds install -a

log "step 5/6: config"
cat > .config <<'EOF'
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_mediatek_filogic_DEVICE_cudy_tr3600-v1=y
CONFIG_PACKAGE_kmod-wireguard=y
CONFIG_PACKAGE_wireguard-tools=y
CONFIG_PACKAGE_luci-proto-wireguard=y
CONFIG_PACKAGE_kmod-gre=y
CONFIG_PACKAGE_gre=y
CONFIG_PACKAGE_kmod-tun=y
CONFIG_PACKAGE_ip-full=y
EOF
make defconfig
grep -q "CONFIG_TARGET_mediatek_filogic_DEVICE_cudy_tr3600-v1=y" .config \
  || { echo "FATAL: device profile missing"; exit 1; }

log "step 6/6: build (dl cache reused across runs)"
make -j$(nproc) download
make -j$(nproc)
log "DONE: bin/targets/mediatek/filogic/"
