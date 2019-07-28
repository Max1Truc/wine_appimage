#!/bin/bash

function main {
  if [ "$(whoami)" != "root" ]
  then
    info "You must execute this script as root !"
    exit 1
  fi

  pushd $(dirname $0)
    if [ "$1" = "clean" ]
    then
      clean
    else
      deps
      create_env
    fi
  popd
}

function info {
  tput setaf 3
  echo $@
  tput sgr0
}

function deps {
  # Tries running apt and temporary disable exit on error
  apt-get >/dev/null
  APT_ERROR_CODE=$?

  # If apt is installed, use it to install dependencies
  if [ $APT_ERROR_CODE -eq 1 ]
  then
    info "> Apt is available, installing dependencies..."
    dpkg --add-architecture i386
    apt-get update
    apt-get install -y apt-utils
    apt-get install -y curl git build-essential libfuse-dev wine libfreetype6:i386 \
        libxext6:i386 libxext6:i386 libudev1:i386 libncurses5:i386 libldap2-dev:i386 \
        libgphoto2-dev:i386 libcrypt-util-perl
  else
    info "> Please manually install these dependencies: curl, git, build-essential, libfuse-dev, wine, libp11-kit0:i386 and base 32-bit libraries"
    info "> If they are installed, press enter, else you can quit by hitting Control-C."
    read
  fi
}

function clean {
  info "> Cleaning..."
  rm -rf build_env WINE.AppDir
}

function create_env {
  info "> Downloading necessary tools..."
  mkdir build_env
  pushd build_env
    info "Downloading appimage tools"
    curl -sL https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -o appimagetool.AppImage
    curl -sL https://github.com/probonopd/linuxdeployqt/releases/download/continuous/linuxdeployqt-continuous-x86_64.AppImage -o linuxdeployqt.AppImage
    curl -sL https://github.com/AppImage/AppImageKit/releases/download/continuous/AppRun-x86_64 -o AppRun
    chmod +x appimagetool.AppImage linuxdeployqt.AppImage AppRun

    info "Downloading and extracting wine"
    curl https://www.playonlinux.com/wine/binaries/linux-amd64/PlayOnLinux-wine-3.13-linux-amd64.pol -o wine.tar.bz2
    mkdir wine
    tar -xf wine.tar.bz2 -C wine

    info "Downloading and building unionfs-fuse"
    git clone https://github.com/rpodgorny/unionfs-fuse.git
    pushd unionfs-fuse
      make
      pushd src
        cp unionfs unionfsctl libunionfs.so ../../
      popd
    popd
  popd

  info "> Creating appdir..."
  mkdir -p WINE.AppDir/usr

  info "Copying base files"
  cp wine.desktop wine.svg WINE.AppDir/
  cp build_env/AppRun WINE.AppDir/

  info "Copying wine"
  cp -r build_env/wine/wineversion/*/* WINE.AppDir/usr/

  info "Copying unionfs-fuse"
  cp build_env/unionfs* WINE.AppDir/usr/bin
  cp build_env/libunionfs.so WINE.AppDir/usr/lib

  info "Preparing appimage for packaging"
  ln /usr/lib/i386-linux-gnu/libgphoto2_port.so /usr/lib/i386-linux-gnu/libgphoto2_port.so.0
  ln /usr/lib/i386-linux-gnu/libgphoto2.so /usr/lib/i386-linux-gnu/libgphoto2.so.2
  ./build_env/linuxdeployqt.AppImage Wine.AppDir/
  rm /usr/lib/i386-linux-gnu/libgphoto2_port.so.0
  rm /usr/lib/i386-linux-gnu/libgphoto2.so.2
}

main $@
