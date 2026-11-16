#!/bin/sh

# Build universal (arm64 + x86_64) OpenSSL 3.x shared libraries to bundle in the app.
#
# Usage: build_openssl.sh [output_dir]
#
# The output directory (default: ../../Release/openssl) receives libssl.3.dylib,
# libcrypto.3.dylib and LICENSE.txt. The libraries use @rpath install names so
# they can be copied to Contents/Frameworks of the application bundle.

set -eu

openssl_ver="3.5.9"
openssl_sha256="603f5602e2eef00d77fbd429d34dcd5822bb301757a1bc9cdb24c670f1eb859a"
min_macos="14.0"
download_attempts=3

script_dir="$(cd "$(dirname "$0")" && pwd)"
out_dir="${1:-$script_dir/../../Release/openssl}"
tarball="openssl-$openssl_ver.tar.gz"
url="https://github.com/openssl/openssl/releases/download/openssl-$openssl_ver/$tarball"

mkdir -p "$out_dir"
out_dir="$(cd "$out_dir" && pwd)"

if [ -f "$out_dir/.version" ] && [ "$(cat "$out_dir/.version")" = "$openssl_ver" ] &&
  [ -f "$out_dir/libssl.3.dylib" ] && [ -f "$out_dir/libcrypto.3.dylib" ]; then
  echo "OpenSSL $openssl_ver is already built in $out_dir"
  exit 0
fi

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/transgui-openssl.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT
trap 'exit 1' HUP INT TERM

attempt=1
while [ "$attempt" -le "$download_attempts" ]; do
  if curl --fail --location --connect-timeout 30 --max-time 600 --output "$work_dir/$tarball" "$url"; then
    break
  fi
  if [ "$attempt" -ge "$download_attempts" ]; then
    echo "Download failed after $download_attempts attempts: $url" >&2
    exit 1
  fi
  echo "Download failed; retrying ($((attempt + 1))/$download_attempts)" >&2
  sleep $((attempt * 5))
  attempt=$((attempt + 1))
done

actual_sha256="$(shasum -a 256 "$work_dir/$tarball" | awk '{print $1}')"
if [ "$actual_sha256" != "$openssl_sha256" ]; then
  echo "Checksum mismatch for $tarball" >&2
  echo "  expected: $openssl_sha256" >&2
  echo "  actual:   $actual_sha256" >&2
  exit 1
fi

jobs="$(sysctl -n hw.ncpu)"

build_arch() {
  arch="$1"
  target="$2"
  src_dir="$work_dir/src-$arch"

  mkdir -p "$src_dir"
  tar -xzf "$work_dir/$tarball" -C "$src_dir" --strip-components=1
  (
    cd "$src_dir"
    ./Configure "$target" shared no-tests no-docs no-module \
      --prefix="$work_dir/install-$arch" \
      "-mmacosx-version-min=$min_macos"
    make -j"$jobs" build_libs

    # Make the libraries relocatable. This must be done per architecture, because
    # the build prefix is different for each one.
    install_name_tool -id "@rpath/libcrypto.3.dylib" libcrypto.3.dylib
    install_name_tool -id "@rpath/libssl.3.dylib" libssl.3.dylib
    crypto_ref="$(otool -L libssl.3.dylib | awk '/libcrypto\.3\.dylib/ {print $1; exit}')"
    # libssl resolves libcrypto next to itself, so the pair also works when it is
    # loaded by absolute path with dlopen.
    install_name_tool -change "$crypto_ref" "@loader_path/libcrypto.3.dylib" libssl.3.dylib
  )
}

build_arch arm64 darwin64-arm64-cc
build_arch x86_64 darwin64-x86_64-cc

for lib in libcrypto.3.dylib libssl.3.dylib; do
  lipo -create "$work_dir/src-arm64/$lib" "$work_dir/src-x86_64/$lib" -output "$out_dir/$lib"
  strip -x "$out_dir/$lib"
  # Editing the load commands invalidates the signature, and arm64 refuses to load
  # unsigned code. Apply an ad-hoc signature; the app build signs them again.
  codesign --force --sign - "$out_dir/$lib"
done

for lib in libcrypto.3.dylib libssl.3.dylib; do
  for arch in arm64 x86_64; do
    if otool -arch "$arch" -L "$out_dir/$lib" | grep -q "$work_dir"; then
      echo "$lib ($arch) still references the temporary build directory" >&2
      exit 1
    fi
  done
done

cp "$work_dir/src-arm64/LICENSE.txt" "$out_dir/LICENSE.txt"
echo "$openssl_ver" > "$out_dir/.version"

lipo -info "$out_dir/libssl.3.dylib" "$out_dir/libcrypto.3.dylib"
