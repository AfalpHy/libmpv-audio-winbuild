#!/bin/bash
set -e

MPV_VERSION="0.42.0"
TARBALL="v${MPV_VERSION}.tar.gz"
SRC_DIR="mpv-${MPV_VERSION}"

echo "=== 1. Downloading mpv v${MPV_VERSION} ==="
if [ ! -f "$TARBALL" ]; then
    curl -L "https://github.com/mpv-player/mpv/archive/refs/tags/${TARBALL}" -o "$TARBALL"
fi

echo "=== 2. Extracting source ==="
if [ ! -d "$SRC_DIR" ]; then
    tar -xf "$TARBALL"
fi

# Move into the extracted directory
cd "$SRC_DIR"

echo "=== 3. Setting up Meson WrapDB and Subprojects ==="
# Ensure subprojects directory exists first
mkdir -p subprojects

# Update the subprojects database from Meson's WrapDB.
meson wrap update-db

# Install wraps only if they don't already exist to prevent interruption
for pkg in expat harfbuzz libpng zlib; do
    if [ ! -f "subprojects/${pkg}.wrap" ]; then
        meson wrap install "$pkg"
    else
        echo "Wrap file for ${pkg} already exists, skipping install."
    fi
done

cat <<EOF > subprojects/libplacebo.wrap
[wrap-git]
url = https://github.com/haasn/libplacebo
revision = v7.387.0
depth = 1
clone-recursive = true
EOF

cat <<EOF > subprojects/libass.wrap
[wrap-git]
revision = 0.17.5
url = https://github.com/libass/libass
depth = 1
EOF

cat <<EOF > subprojects/ffmpeg.wrap
[wrap-git]
url = https://gitlab.freedesktop.org/gstreamer/meson-ports/ffmpeg.git
revision = meson-9.0
depth = 1
[provide]
libavcodec = libavcodec_dep
libavdevice = libavdevice_dep
libavfilter = libavfilter_dep
libavformat = libavformat_dep
libavutil = libavutil_dep
libswresample = libswresample_dep
libswscale = libswscale_dep
EOF

echo "=== 4. Configuring the Build (Audio-Only, Non-GPL Shared libmpv) ==="
# Ensure your cross-file.txt is sitting in the parent folder, or adjust the path below
rm -rf build
meson setup build \
  --cross-file ../cross-file.txt \
  -Dlibmpv=true \
  -Ddefault_library=shared \
  -Dprefer_static=true \
  -Dc_link_args='-static' \
  -Dcpp_link_args='-static' \
  -Dffmpeg:default_library=static \
  -Dlibass:default_library=static \
  -Dexpat:default_library=static \
  -Dharfbuzz:default_library=static \
  -Dzlib:default_library=static \
  -Dfreetype2:default_library=static \
  -Dfribidi:default_library=static \
  -Dlibpng:default_library=static \
  -Dlibplacebo:vulkan=disabled \
  -Dlibplacebo:opengl=disabled \
  -Dlibplacebo:shaderc=disabled \
  -Dlibplacebo:lcms=disabled \
  -Dlibplacebo:demos=false \
  -Dgpl=false \
  -Dd3d-hwaccel=disabled \
  -Dd3d9-hwaccel=disabled \
  -Dd3d11=disabled \
  -Ddirect3d=disabled

echo "=== 5. Compiling libmpv ==="
ninja -C build libmpv-2.dll

x86_64-w64-mingw32-strip --strip-unneeded build/libmpv-2.dll

echo "=== Build Complete! ==="