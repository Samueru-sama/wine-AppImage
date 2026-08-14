#!/bin/sh

set -eu

ARCH=$(uname -m)

echo "Installing package dependencies..."
echo "---------------------------------------------------------------"
pacman -Syu --noconfirm wine cabextract sdl2 pipewire-audio pipewire-jack harfbuzz gst-plugins-bad gst-plugins-base gst-plugins-base-libs gst-plugins-good gst-plugins-ugly gst-libav gstreamer 7zip unzip

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
get-debloated-pkgs --add-common --prefer-nano ffmpeg-mini

if [ "$ARCH" = 'x86_64' ]; then
	sudo pacman -S --noconfirm mingw-w64-binutils
fi

# Comment this out if you need an AUR package
make-aur-package zenity-rs-bin

# Install latest winetricks
wget --retry-connrefused --tries=30 https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks -O ./AppDir/bin/winetricks
chmod +x ./AppDir/bin/winetricks

# If the application needs to be manually built that has to be done down here
