#!/bin/sh

# Optional Flatpak applications. Kept separate from the main desktop install so
# Flatpak and the Flathub remote are only configured when wanted.

set -eu

command -v sudo >/dev/null 2>&1 || {
  echo "sudo is required" >&2
  exit 1
}

sudo -v

# Use the system installation explicitly so the remote and applications do not
# depend on root's Flatpak defaults.
sudo xbps-install -Sy flatpak
sudo flatpak remote-add --system --if-not-exists \
  flathub https://dl.flathub.org/repo/flathub.flatpakrepo

sudo flatpak install --system --assumeyes flathub \
  no.bragefuglseth.Keypunch \
  io.dbeaver.DBeaverCommunity \
  com.getpostman.Postman

# Wayland crash issue fix. Enable Wayland Socket: Grant the Postman Flatpak permission to access the Wayland display socket.
flatpak override --user --socket=wayland com.getpostman.Postman
