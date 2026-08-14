#!/bin/sh

set -eu

ARCH=$(uname -m)
VERSION=$(pacman -Q wine | awk '{print $2; exit}') # example command to get version of application here
export ARCH VERSION
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export ICON=https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-icon-theme/bcf6aa9582f676e1c93d0022319e6055cd1f2de2/Papirus/64x64/apps/wine.svg
export DESKTOP=/usr/share/applications/wine.desktop
export APPNAME=wine
export DEPLOY_SDL=1
export DEPLOY_PIPEWIRE=1
export DEPLOY_GSTREAMER=1
export DEPLOY_VULKAN=1
export DEPLOY_OPENGL=1
export WINEPREFIX=/tmp/wine

mkdir -p "$WINEPREFIX"

# Deploy dependencies
quick-sharun \
	/usr/bin/wine*             \
	/usr/lib/wine              \
	/usr/bin/msidb             \
	/usr/bin/msiexec           \
	/usr/bin/notepad           \
	/usr/bin/regedit           \
	/usr/bin/regsvr32          \
	/usr/bin/widl              \
	/usr/bin/wmc               \
	/usr/bin/wrc               \
	/usr/bin/function_grep.pl  \
	/usr/bin/cabextract        \
	/usr/lib/libfreetype.so*   \
	/usr/lib/libharfbuzz*      \
	/usr/lib/libgraphite*      \
	/usr/lib/libavcodec.so*    \
	/usr/lib/libavdevice.so*   \
	/usr/lib/libavfilter.so*   \
	/usr/lib/libavformat.so*   \
	/usr/lib/libavutil.so*     \
	/usr/lib/libswresample.so* \
	/usr/lib/libswscale.so*    \
	/usr/bin/wget              \
	/usr/bin/zenity            \
	/usr/bin/unzip             \
	/usr/lib/7zip/7z           \
	/usr/lib/7zip/7z.so

# quick-sharun replaces lib/wine/x86_64-unix/wine with a
# sharun hardlink so have to restore the real binay (keep reading to see why)
rm -f ./AppDir/lib/wine/x86_64-unix/wine
cp /usr/lib/wine/x86_64-unix/wine ./AppDir/lib/wine/x86_64-unix/wine

# make sure to have the wine from /usr/bin and NOT from /usr/lib here
cp /usr/bin/wine ./AppDir/shared/bin/wine

# it turns out that wine itself performs userland-execve on the wine binary
# in lib, and it checks its PT_INTERP before doing so, so we have to set it manually
# to our bundled dynamic linker, which sharun will automatically copy to /tmp
patchelf --set-interpreter /tmp/.ld-sharun.so.67 ./AppDir/lib/wine/x86_64-unix/wine

# mark the launcher and wineserver as pyinstaller-like so anylinux-sharun uses
# real execve for them (userland-execve breaks /proc/self/exe, which the launcher
# relies on to locate ntdll.so). objcopy MUST run after patchelf: patchelf moves
# the section table and sharun's ELF parser then fails to read the binary, so the
# section has to be added last to keep the section table at the end of the file.
:> /tmp/.wine-pydata
for winebin in ./AppDir/shared/bin/wine ./AppDir/shared/bin/wineserver; do
	[ -f "$winebin" ] || continue
	patchelf --set-interpreter /tmp/.ld-sharun.so.67 "$winebin"
	objcopy --add-section pydata=/tmp/.wine-pydata \
		--set-section-flags pydata=noload,readonly "$winebin"
done

# strip windows libs, inspired by alpine linux:
# https://gitlab.alpinelinux.org/alpine/aports/-/blob/master/community/wine/APKBUILD
if [ "$ARCH" = 'x86_64' ]; then
	x86_64-w64-mingw32-strip -R .comment --strip-unneeded ./AppDir/lib/wine/x86_64-windows/*.dll
	i686-w64-mingw32-strip   -R .comment --strip-unneeded ./AppDir/lib/wine/i386-windows/*.dll
fi

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the test fails due to the app
# having issues running in the CI use --simple-test instead
quick-sharun --test ./dist/*.AppImage explorer.exe
