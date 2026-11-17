#!/usr/bin/env bash
set -euo pipefail
cd /work
test "$(dpkg --print-architecture)" = arm64
test "$(getconf GNU_LIBC_VERSION)" = 'glibc 2.31'

# Reuse the pinned upstream relocation patches and bundling functions.
source <(sed '/^set -x$/,$d' build.sh)
set -euo pipefail
J=${BUILD_JOBS:-2}
export CMAKE_BUILD_PARALLEL_LEVEL="$J"
export MAKEFLAGS="-j$J"

fetch_cmake() { :; }
build_cmake() { :; }
fetch_patchelf() { :; }
build_patchelf() { ln -sf /usr/bin/patchelf ./patchelf; }

fetch_plugin() {
    local owner=$1 plugin=$2 revision
    case "$plugin" in
        lua) revision=6da5d6cedb853380ed1b5b9b6979cb1a9c028353 ;;
        octagram) revision=57d18b9f58e5284bd891d559f6bdd16cf60341e9 ;;
        charcode) revision=55e7f563e999802d41a13ba02657c1be4b2011b4 ;;
        *) return 1 ;;
    esac
    git clone "https://github.com/$owner/librime-$plugin.git" "plugins/$plugin"
    git -C "plugins/$plugin" checkout --detach "$revision"
    if [ -f "plugins/$plugin/action-install.sh" ]; then
        (cd "plugins/$plugin" && bash ./action-install.sh)
    fi
}

fetch_librime() {
    git clone --depth 1 --branch 1.17.0 https://github.com/rime/librime.git
    (
        cd librime
        patch -p1 < "$H/patches/librime/relocatable-plugins.patch"
        git clone --depth 1 --branch 1.2.2 https://github.com/google/snappy.git deps/snappy
        git clone --depth 1 --branch v0.6.0 https://github.com/google/glog.git deps/glog
        git clone --depth 1 --branch 1.23 https://github.com/google/leveldb.git deps/leveldb
        git clone --depth 1 --branch v0.3.1 https://github.com/s-yata/marisa-trie.git deps/marisa-trie
        git clone --depth 1 --branch ver.1.4.2 https://github.com/BYVoid/OpenCC.git deps/opencc
        git clone --depth 1 --branch 0.8.0 https://github.com/jbeder/yaml-cpp.git deps/yaml-cpp
        (cd deps/opencc && patch -p1 < "$H/patches/opencc/0001-relocatable-opencc.patch")
        fetch_plugin rime charcode
        fetch_plugin lotem octagram
        fetch_plugin hchunhui lua
        patch -p1 < "$H/patches/librime/charcode-drop-boost-asio.patch"
    )
}

fetch_plum() {
    git clone https://github.com/rime/plum.git
    git -C plum checkout b1be1969f914cc005add4090631b855db00c2591
    (cd plum && make minimal && mv output output-minimal)
}

printf '%s\n' 'AppImage/appimagetool aarch64; Debian bullseye native build' > appimagetool-version
printf '%s\n' "${BUILD_RUN_URL:-local}" > ci-version
fetch_boost_mini
fetch_librime
fetch_ibus_rime
fetch_plum
build

# Keep the C++ runtime private instead of requiring Kylin's GCC runtime to match.
patch_lib "/usr/lib/$(gcc -print-multiarch)" libstdc++.so.6
patch_lib "/lib/$(gcc -print-multiarch)" libgcc_s.so.1

mkdir -p AppDir/usr/share/rime-data
cp -a plum/output-minimal/. AppDir/usr/share/rime-data/
cp -a librime/share/opencc/. AppDir/usr/share/rime-data/
mkdir -p /project/dist
{
    printf 'Build run: %s\n' "${BUILD_RUN_URL:-local}"
    cat /etc/os-release
    getconf GNU_LIBC_VERSION
    gcc --version | head -1
    cmake --version | head -1
    dpkg-query -W
    find . -type d -name .git -print | sort | while IFS= read -r repo_git; do
        printf '\n%s ' "${repo_git%/.git}"
        git -C "${repo_git%/.git}" rev-parse HEAD
    done
} > /project/dist/BUILD-INFO.txt

cp /project/dist/BUILD-INFO.txt AppDir/usr/share/ibus-rime/BUILD-INFO.txt
# The original plugin loader needs both library and plugin paths available.
file AppDir/usr/bin/ibus-engine-rime
readelf -h AppDir/usr/bin/ibus-engine-rime | grep AArch64
