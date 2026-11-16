#!/bin/sh

# Install the Free Pascal + Lazarus toolchain used to build the macOS app.
#
# Everything is installed in a user-writable directory (no sudo needed):
#   $TOOLCHAIN_DIR/fpc-<version>   Free Pascal (arm64 and x86_64 compilers)
#   $TOOLCHAIN_DIR/lazarus         Lazarus (lazbuild, lazres), built from source
#   $TOOLCHAIN_DIR/shim            assembler shim, see fpc-asm-shim/clang
#
# Requires an Apple Silicon Mac. The x86_64 compiler runs under Rosetta 2.

set -ex

fpc_ver="3.2.2"
fpc_dmg="fpc-${fpc_ver}.intelarm64-macosx.dmg"
fpc_sha256="05d4510c8c887e3c68de20272abf62171aa5b2ef1eba6bce25e4c0bc41ba8b7d"
fpc_url="https://downloads.sourceforge.net/project/freepascal/Mac%20OS%20X/${fpc_ver}/${fpc_dmg}"
lazarus_tag="lazarus_4_8"
lazarus_commit="62c14a4d18c81f222127d42ce9b89b922c63fcbf"
lazarus_url="https://gitlab.com/freepascal.org/lazarus/lazarus.git"
stamp="fpc-${fpc_ver}+${lazarus_tag}+shim1"

toolchain_dir="${TOOLCHAIN_DIR:-$HOME/pascal-toolchain}"
download_attempts=3
download_timeout="${download_timeout:-900}"
download_backoff=5
script_dir="$(cd "$(dirname "$0")" && pwd)"

if [ "$(uname -m)" != "arm64" ]; then
  echo "An Apple Silicon Mac is required to build the application." >&2
  exit 1
fi

if ! arch -x86_64 /usr/bin/true 2> /dev/null; then
  echo "Rosetta 2 is required to run the x86_64 compiler. Run: softwareupdate --install-rosetta" >&2
  exit 1
fi

fpc_dir="$toolchain_dir/fpc-$fpc_ver"
lazarus_dir="$toolchain_dir/lazarus"

if [ -f "$toolchain_dir/.installed" ] && [ "$(cat "$toolchain_dir/.installed")" = "$stamp" ] &&
  [ -x "$lazarus_dir/lazbuild" ] && [ -x "$lazarus_dir/tools/lazres" ]; then
  echo "Toolchain $stamp is already installed in $toolchain_dir"
  exit 0
fi

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/transgui-deps.XXXXXX")"
fpc_mount=""

detach_disk_image() {
  detach_device=$1
  detach_attempt=1

  sync
  while ! hdiutil detach "$detach_device"; do
    if [ "$detach_attempt" -ge 5 ]; then
      echo "Failed to detach $detach_device after $detach_attempt attempts." >&2
      return 1
    fi

    echo "Failed to detach $detach_device; retrying in 2 seconds." >&2
    sleep 2
    detach_attempt=$((detach_attempt + 1))
  done
}

cleanup() {
  if [ -n "$fpc_mount" ]; then
    detach_disk_image "$fpc_mount" > /dev/null || true
  fi
  rm -rf "$work_dir"
}

trap cleanup EXIT
trap 'exit 1' HUP INT TERM

download_url() {
  download_url_value="$1"
  download_destination="$2"
  partial="${download_destination}.part"
  attempt=1

  while [ "$attempt" -le "$download_attempts" ]; do
    rm -f "$partial"
    if curl --fail --location \
      --connect-timeout 30 --max-time "$download_timeout" \
      --output "$partial" "$download_url_value"; then
      mv "$partial" "$download_destination" || return 1
      return 0
    fi

    if [ "$attempt" -lt "$download_attempts" ]; then
      next_attempt=$((attempt + 1))
      echo "Download failed; retrying ($next_attempt/$download_attempts)" >&2
      sleep $((attempt * download_backoff))
    fi
    attempt=$((attempt + 1))
  done

  echo "Download failed after $download_attempts attempts: $download_url_value" >&2
  rm -f "$partial"
  return 1
}

install_fpc() {
  download_url "$fpc_url" "$work_dir/fpc.dmg"
  actual_sha256="$(shasum -a 256 "$work_dir/fpc.dmg" | awk '{print $1}')"
  if [ "$actual_sha256" != "$fpc_sha256" ]; then
    echo "Checksum mismatch for $fpc_dmg" >&2
    echo "  expected: $fpc_sha256" >&2
    echo "  actual:   $actual_sha256" >&2
    exit 1
  fi

  fpc_mount="$work_dir/mnt"
  mkdir -p "$fpc_mount"
  hdiutil attach -nobrowse -readonly -mountpoint "$fpc_mount" "$work_dir/fpc.dmg"

  fpc_pkg="$fpc_mount/fpc-${fpc_ver}-intelarm64-macosx.mpkg/Contents/Packages/fpc-${fpc_ver}-intelarm64-macosx.pkg"
  if [ ! -e "$fpc_pkg" ]; then
    echo "No installer package found in $fpc_dmg" >&2
    exit 1
  fi
  pkgutil --expand-full "$fpc_pkg" "$work_dir/fpc-expanded"
  detach_disk_image "$fpc_mount"
  fpc_mount=""

  rm -rf "$fpc_dir"
  mkdir -p "$fpc_dir"
  cp -R "$work_dir/fpc-expanded/Payload/usr/local/bin" "$work_dir/fpc-expanded/Payload/usr/local/lib" \
    "$work_dir/fpc-expanded/Payload/usr/local/share" "$fpc_dir/"
}

configure_fpc() {
  mkdir -p "$fpc_dir/etc" "$toolchain_dir/shim"
  cp "$script_dir/fpc-asm-shim/clang" "$toolchain_dir/shim/clang"
  chmod +x "$toolchain_dir/shim/clang"

  "$fpc_dir/bin/fpcmkcfg" -d "basepath=$fpc_dir/lib/fpc/$fpc_ver" -o "$fpc_dir/etc/fpc.cfg"
  {
    echo ""
    echo "# Assembler shim for aarch64-darwin (see setup/macosx/fpc-asm-shim/clang)"
    echo "-FD$toolchain_dir/shim"
  } >> "$fpc_dir/etc/fpc.cfg"
}

install_lazarus() {
  rm -rf "$lazarus_dir"
  git clone --depth 1 --branch "$lazarus_tag" "$lazarus_url" "$lazarus_dir"
  actual_commit="$(git -C "$lazarus_dir" rev-parse HEAD)"
  if [ "$actual_commit" != "$lazarus_commit" ]; then
    echo "Unexpected Lazarus commit for $lazarus_tag" >&2
    echo "  expected: $lazarus_commit" >&2
    echo "  actual:   $actual_commit" >&2
    exit 1
  fi

  # The Lazarus makefiles are not safe to run in parallel.
  (
    cd "$lazarus_dir"
    PPC_CONFIG_PATH="$fpc_dir/etc" PATH="$fpc_dir/bin:$PATH" \
      make lazbuild LCL_PLATFORM=cocoa CPU_TARGET=aarch64 OS_TARGET=darwin \
      PP="$fpc_dir/bin/ppca64" FPC="$fpc_dir/bin/fpc"
  )
}

mkdir -p "$toolchain_dir"
install_fpc
configure_fpc
install_lazarus

if [ ! -x "$lazarus_dir/lazbuild" ] || [ ! -x "$lazarus_dir/tools/lazres" ]; then
  echo "lazbuild or lazres was not built" >&2
  exit 1
fi

echo "$stamp" > "$toolchain_dir/.installed"
"$fpc_dir/bin/ppca64" -iV
