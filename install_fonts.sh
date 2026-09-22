#!/bin/sh

# Optional desktop fonts. Kept separate from the main desktop install because
# the Nerd Fonts collection is large and only needed when icon-patched fonts
# are wanted in terminals, editors, or status bars.

set -eu

command -v sudo >/dev/null 2>&1 || {
  echo "sudo is required" >&2
  exit 1
}

sudo -v

sudo xbps-install -Sy \
  noto-fonts-emoji \
  noto-fonts-ttf \
  nerd-fonts

if command -v fc-cache >/dev/null 2>&1; then
  fc-cache -f
fi

echo "Desktop and Nerd Fonts installed. Select a Nerd Font in your terminal/editor config."
