#!/bin/sh

# Build "Transmission Remote GUI.app" as a universal (arm64 + x86_64) application
# and package it in a disk image.
#
# Usage: create_app_new.sh [lazarus_dir]
#
# Environment:
#   TOOLCHAIN_DIR      toolchain installed by install_deps.sh (default: ~/pascal-toolchain)
#   CODESIGN_IDENTITY  signing identity, e.g. "Developer ID Application: Name (TEAMID)".
#                      Default: ad-hoc signature, which is only good for local use.
#   NOTARY_PROFILE     notarytool keychain profile (see "xcrun notarytool store-credentials").
#                      When set, the disk image is notarized and stapled. It requires a
#                      Developer ID identity. No credentials are ever read from the repository.
#   CI                 when set, dependencies are not installed and the image is not opened.

set -ex

toolchain_dir="${TOOLCHAIN_DIR:-$HOME/pascal-toolchain}"
fpc_dir="$toolchain_dir/fpc-3.2.2"
lazarus_dir="${1:-$toolchain_dir/lazarus}"
lazbuild_bin="$lazarus_dir/lazbuild"
sign_identity="${CODESIGN_IDENTITY:--}"
notary_profile="${NOTARY_PROFILE-}"

if [ -n "$notary_profile" ] && [ "$sign_identity" = "-" ]; then
  echo "NOTARY_PROFILE requires CODESIGN_IDENTITY to be a Developer ID identity." >&2
  exit 1
fi

prog_ver="$(cat ../../VERSION.txt)"
build="$(git rev-list --abbrev-commit --max-count=1 HEAD ../..)"

if [ -z "${CI-}" ]; then
  ./install_deps.sh
fi

fpc_bin="$fpc_dir/bin/fpc"
if [ ! -x "$fpc_bin" ]; then
  echo "Unable to find fpc at $fpc_bin. Run install_deps.sh first." >&2
  exit 1
fi
if [ ! -x "$lazbuild_bin" ]; then
  echo "Unable to find lazbuild at $lazbuild_bin. Run install_deps.sh first." >&2
  exit 1
fi

PPC_CONFIG_PATH="$fpc_dir/etc"
export PPC_CONFIG_PATH

fpc_ver="Free Pascal Compiler version $("$fpc_bin" -iV)"
lazarus_ver="$("$lazbuild_bin" -v)"
exename=../../transgui
appname="Transmission Remote GUI"
dmg_dist_file="../../Release/transgui-$prog_ver.dmg"
dmg_temp_file="$dmg_dist_file.tmp.dmg"
dmgfolder=./Release
appfolder="$dmgfolder/$appname.app"
openssl_dir=../../Release/openssl
mount_device=""
remove_dmg_temp=0
remove_dmgfolder=0
remove_tmp_dmg=0
lazarus_pcp=""
build_dir=""

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
  status=$?
  cleanup_status=0

  trap '' HUP INT TERM
  trap - 0
  set +e

  if [ -n "$mount_device" ]; then
    detach_status=0
    detach_disk_image "$mount_device" || detach_status=$?
    if [ "$detach_status" -eq 0 ]; then
      mount_device=""
    else
      cleanup_status=$detach_status
      remove_tmp_dmg=0
    fi
  fi
  if [ "$remove_dmg_temp" -eq 1 ]; then
    rm -f "$dmg_temp_file" || cleanup_status=$?
  fi
  if [ "$remove_tmp_dmg" -eq 1 ]; then
    rm -f tmp.dmg || cleanup_status=$?
  fi
  if [ "$remove_dmgfolder" -eq 1 ]; then
    rm -rf "$dmgfolder" || cleanup_status=$?
  fi
  if [ -e ../../about.lfm.bak ]; then
    mv ../../about.lfm.bak ../../about.lfm || cleanup_status=$?
  fi
  if [ -n "$lazarus_pcp" ]; then
    rm -rf "$lazarus_pcp" || :
  fi
  if [ -n "$build_dir" ]; then
    rm -rf "$build_dir" || :
  fi

  if [ "$status" -eq 0 ]; then
    status=$cleanup_status
  fi
  exit "$status"
}

if [ -e ../../about.lfm.bak ]; then
  echo "../../about.lfm.bak already exists; refusing to overwrite it." >&2
  exit 1
fi
if [ -e "$dmg_dist_file" ] && [ ! -f "$dmg_dist_file" ]; then
  echo "$dmg_dist_file exists and is not a regular file." >&2
  exit 1
fi
if [ -e "$dmg_temp_file" ] && [ ! -f "$dmg_temp_file" ]; then
  echo "$dmg_temp_file exists and is not a regular file." >&2
  exit 1
fi

trap cleanup 0
trap 'exit 1' HUP INT TERM

lazarus_pcp="$(mktemp -d "${TMPDIR:-/tmp}/transgui-lazarus-pcp.XXXXXX")" || exit 1
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/transgui-build.XXXXXX")" || exit 1

cleanup_lazbuild_state() {
  rm -rf ../../units ../../lib
  mkdir -p ../../units ../../lib "$lazarus_pcp"
}

# Compile the application for one CPU architecture. The LCL and the other
# packages are rebuilt too (-r), so that they are compiled by the same compiler
# and through the assembler shim installed by install_deps.sh.
build_arch() {
  arch="$1"
  compiler="$2"

  cleanup_lazbuild_state
  "$lazbuild_bin" -B -r ../../trcomp.lpk --lazarusdir="$lazarus_dir" --compiler="$compiler" --cpu="$arch" --os=darwin --widgetset=cocoa --pcp="$lazarus_pcp"
  "$lazbuild_bin" -B ../../transgui.lpi --lazarusdir="$lazarus_dir" --compiler="$compiler" --cpu="$arch" --os=darwin --widgetset=cocoa --pcp="$lazarus_pcp"
  cp ../../units/transgui "$build_dir/transgui.$arch"
}

sign_path() {
  if [ "$sign_identity" = "-" ]; then
    codesign --force --sign - "$1"
  else
    codesign --force --options runtime --timestamp --sign "$sign_identity" "$1"
  fi
}

mkdir -p ../../Release/
sed -i.bak "s/'Version %s'/'Version %s Build $build'#13#10'Compiled by: $fpc_ver, Lazarus v$lazarus_ver'/" ../../about.lfm

build_arch aarch64 "$fpc_dir/bin/ppca64"
build_arch x86_64 "$fpc_dir/bin/ppcx64"

lipo -create "$build_dir/transgui.aarch64" "$build_dir/transgui.x86_64" -output "$exename"
if [ "$(lipo -archs "$exename" | tr ' ' '\n' | sort | tr '\n' ' ')" != "arm64 x86_64 " ]; then
  echo "$exename is not a universal arm64 + x86_64 binary." >&2
  exit 1
fi
strip "$exename"

./build_openssl.sh "$openssl_dir"

remove_dmgfolder=1
rm -rf "$appfolder"

echo "Creating $appfolder..."
mkdir -p "$appfolder/Contents/MacOS"
mkdir -p "$appfolder/Contents/Resources/lang"
mkdir -p "$appfolder/Contents/Frameworks"

mv "$exename" "$appfolder/Contents/MacOS"
# Data files must not be inside Contents/MacOS: codesign treats that folder as code.
cp ../../lang/transgui.* "$appfolder/Contents/Resources/lang"

cp ../../history.txt "$dmgfolder"
cp ../../README.md "$dmgfolder"

cp PkgInfo "$appfolder/Contents"
cp transgui.icns "$appfolder/Contents/Resources"
cp "$openssl_dir/libssl.3.dylib" "$openssl_dir/libcrypto.3.dylib" "$appfolder/Contents/Frameworks"
cp "$openssl_dir/LICENSE.txt" "$appfolder/Contents/Resources/openssl-LICENSE.txt"
sed -e "s/@prog_ver@/$prog_ver/" Info.plist > "$appfolder/Contents/Info.plist"

# Sign the nested code first, then the application itself.
sign_path "$appfolder/Contents/Frameworks/libcrypto.3.dylib"
sign_path "$appfolder/Contents/Frameworks/libssl.3.dylib"
sign_path "$appfolder"
codesign --verify --strict --verbose=2 "$appfolder"

ln -s /Applications "$dmgfolder/Drag \"Transmission Remote GUI\" here!"

hdiutil create -ov -anyowners -volname "transgui-v$prog_ver" -format UDRW -srcfolder ./Release -fs HFS+ "tmp.dmg"
remove_tmp_dmg=1

remove_tmp_dmg=0
attach_status=0
attach_output="$(hdiutil attach -readwrite -noautoopen "tmp.dmg")" || attach_status=$?
mount_device="$(printf '%s\n' "$attach_output" | awk 'NR == 1 && $1 ~ /^\/dev\/disk[0-9]+(s[0-9]+)*$/ {print $1}')"
if [ -z "$mount_device" ]; then
  echo "Failed to determine the mounted disk image device." >&2
  if [ "$attach_status" -ne 0 ]; then
    exit "$attach_status"
  fi
  exit 1
fi
remove_tmp_dmg=1
if [ "$attach_status" -ne 0 ]; then
  exit "$attach_status"
fi
mount_volume="$(printf '%s\n' "$attach_output" | awk -F '\t' 'NF >= 3 && $NF ~ /^\// {volume=$NF} END {print volume}')"
if [ -z "$mount_volume" ]; then
  echo "Failed to determine the mounted disk image volume." >&2
  exit 1
fi
cp transgui.icns "$mount_volume/.VolumeIcon.icns"
SetFile -c icnC "$mount_volume/.VolumeIcon.icns"
SetFile -a C "$mount_volume"

detach_disk_image "$mount_device"
mount_device=""
remove_dmg_temp=1
rm -f "$dmg_temp_file"
hdiutil convert tmp.dmg -format UDBZ -imagekey zlib-level=9 -o "$dmg_temp_file"

if [ "$sign_identity" != "-" ]; then
  codesign --force --timestamp --sign "$sign_identity" "$dmg_temp_file"
fi
if [ -n "$notary_profile" ]; then
  xcrun notarytool submit "$dmg_temp_file" --keychain-profile "$notary_profile" --wait
  xcrun stapler staple "$dmg_temp_file"
fi

mv -f "$dmg_temp_file" "$dmg_dist_file"
remove_dmg_temp=0

if [ -z "${CI-}" ]; then
  open "$dmg_dist_file"
fi
