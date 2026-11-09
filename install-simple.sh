#!/bin/sh
# Void x86_64 glibc / Intel / Sway + Noctalia. Run as your normal user.
set -eu

if [ "$(id -u)" -eq 0 ]; then
  echo "Run as your normal user, without sudo; the script uses sudo when needed." >&2
  exit 1
fi
if ! command -v xbps-uhelper >/dev/null 2>&1 || [ "$(xbps-uhelper arch)" != x86_64 ]; then
  echo "This script requires Void Linux x86_64 glibc." >&2
  exit 1
fi

DOTFILES_REPO=https://github.com/simple-sketch/dotfiles-stow
DOTFILES_DIR="$HOME/dotfiles-stow"
UNIVERSAL_REPO=https://universalrepo.pages.dev/void
UNIVERSAL_FINGERPRINT=0f:fa:c3:8e:fd:cd:c9:52:88:f0:34:ca:df:6c:c6:fa
USER_NAME=$(id -un)
sudo -v

# Do not silently replace a different session or logging setup.
for service in seatd turnstiled rsyslogd syslog-ng metalog; do
  if [ -e "/var/service/$service" ] || [ -L "/var/service/$service" ]; then
    echo "Disable $service before using this elogind/socklog setup." >&2
    exit 1
  fi
done

# Keep real service directories intact; create/repair only conventional links.
enable_service() {
  [ -d "/etc/sv/$1" ] || {
    echo "Missing service: /etc/sv/$1" >&2
    return 1
  }
  if [ -L "/var/service/$1" ] || [ ! -e "/var/service/$1" ]; then
    sudo ln -sfnT "/etc/sv/$1" "/var/service/$1"
  elif [ ! -d "/var/service/$1" ]; then
    echo "Not replacing existing file: /var/service/$1" >&2
    return 1
  fi
  # runsvdir discovers newly added services asynchronously.
  attempts=0
  until sudo sv status "/var/service/$1" >/dev/null 2>&1; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 15 ]; then
      echo "runit did not discover $1 within 15 seconds." >&2
      return 1
    fi
    sleep 1
  done
  sudo sv -w 15 start "/var/service/$1"
}

# Never overwrite unrelated files or links.
ensure_link() {
  if [ -L "$2" ] && [ "$(readlink "$2")" = "$1" ]; then
    return 0
  fi
  if [ -e "$2" ] || [ -L "$2" ]; then
    echo "Not replacing existing file: $2" >&2
    return 1
  fi
  sudo ln -sfnT "$1" "$2"
}

echo "==> Repositories and packages"
# XBPS prompts for the repository key on first use. Check its fingerprint
# before installing anything from this third-party repository.
echo "Expected UniversalRepository fingerprint: $UNIVERSAL_FINGERPRINT"
sudo xbps-install -i --repository="$UNIVERSAL_REPO" -S
repo_details=$(xbps-query -i --repository="$UNIVERSAL_REPO" -vL)
if ! printf '%s\n' "$repo_details" | grep -Fq "$UNIVERSAL_FINGERPRINT" ||
  ! printf '%s\n' "$repo_details" | grep -Fq "$UNIVERSAL_REPO (RSA signed)"; then
  echo "UniversalRepository signature/fingerprint check failed." >&2
  exit 1
fi
sudo mkdir -p /etc/xbps.d
repo_config=/etc/xbps.d/10-universalrepository.conf
if [ -e "$repo_config" ] || [ -L "$repo_config" ]; then
  if ! grep -Fxq "repository=$UNIVERSAL_REPO" "$repo_config"; then
    echo "Conflicting repository configuration: $repo_config" >&2
    exit 1
  fi
else
  printf 'repository=%s\n' "$UNIVERSAL_REPO" | sudo tee "$repo_config" >/dev/null
fi
sudo xbps-install -Syu xbps
sudo xbps-install -Sy void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree
sudo xbps-install -Syu

# Already-installed packages are skipped by XBPS. No forced reinstalls.
sudo xbps-install -y \
  socklog-void dbus elogind polkit \
  linux-firmware-intel mesa-dri vulkan-loader mesa-vulkan-intel intel-video-accel \
  xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
  xdg-utils xdg-user-dirs xdg-user-dirs-gtk dejavu-fonts-ttf \
  python3 python3-gobject python3-cairo gtk+3 \
  engrampa Thunar tumbler ffmpegthumbnailer thunar-volman thunar-archive-plugin \
  gvfs tldr github-cli gnome-keyring perl-File-MimeInfo shfmt shellcheck ddcutil \
  kitty swayimg nodejs openjdk25 delta git eza bash bash-completion stow neovide \
  shikane alacritty wmenu vim newsboat playerctl libnotify btop fastfetch \
  brightnessctl base-devel wl-clipboard sway foot firefox vlc xtools vsv lazygit \
  neovim ghostty rsync yazi bat upower ffmpeg 7zip unzip zip unrar ouch jq poppler \
  fd ripgrep fzf zoxide resvg ImageMagick noctalia sound-theme-freedesktop \
  bibata-cursor-theme curl util-linux bluez alsa-utils alsa-pipewire \
  libspa-bluetooth pipewire wireplumber wireplumber-elogind tlp tlp-pd iwd

echo "==> System configuration and services"
sudo usermod -aG socklog,video,bluetooth "$USER_NAME"
sudo mkdir -p /etc/alsa/conf.d /etc/tlp.d
ensure_link /usr/share/alsa/alsa.conf.d/50-pipewire.conf /etc/alsa/conf.d/50-pipewire.conf
ensure_link /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf /etc/alsa/conf.d/99-pipewire-default.conf
# Preserve an existing TLP profile; only supply a default on first install.
if [ ! -e /etc/tlp.d/99-default-power-saver.conf ] && [ ! -L /etc/tlp.d/99-default-power-saver.conf ]; then
  printf '%s\n' 'TLP_AUTO_SWITCH=0' 'TLP_PROFILE_DEFAULT=SAV' |
    sudo tee /etc/tlp.d/99-default-power-saver.conf >/dev/null
fi

for service in socklog-unix nanoklogd dbus elogind polkitd tlp tlp-pd bluetoothd; do
  enable_service "$service"
done
sudo udevadm control --reload-rules
sudo udevadm trigger
sudo tlp start
sudo rfkill unblock bluetooth || true
sudo xbps-alternatives -s vim -g vim

# Never switch an active network manager during installation.
network_managed=false
for service in wpa_supplicant NetworkManager connmand wicd; do
  if [ -e "/var/service/$service" ] || [ -L "/var/service/$service" ]; then
    network_managed=true
  fi
done
if [ "$network_managed" = false ]; then
  enable_service iwd
else
  echo "Keeping the existing network service; iwd was installed but not enabled."
fi

echo "==> Dotfiles"
if [ ! -e "$DOTFILES_DIR" ] && [ ! -L "$DOTFILES_DIR" ]; then
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi
# Reuse local edits; never pull, reset, or overwrite an existing checkout.
origin=$(git -C "$DOTFILES_DIR" remote get-url origin)
case "$origin" in
"$DOTFILES_REPO" | "$DOTFILES_REPO.git") ;;
*)
  echo "Unexpected dotfiles origin: $origin" >&2
  exit 1
  ;;
esac

mkdir -p "$HOME/.config/pipewire/pipewire.conf.d" \
  "$HOME/.local/share" "$HOME/.local/state" "$HOME/.local/bin" \
  "$HOME/Pictures/Screenshots" "$HOME/Pictures/Wallpapers"
xdg-user-dirs-update

# Back up only regular shell/editor defaults that commonly come from /etc/skel.
# Symlinks are left alone so reruns do not back up Stow's own links.
backup_dir=
for name in .bashrc .bash_profile .inputrc .vimrc; do
  if [ -f "$HOME/$name" ] && [ ! -L "$HOME/$name" ]; then
    if [ -z "$backup_dir" ]; then
      mkdir -p "$HOME/.dotfiles-backup"
      backup_dir=$(mktemp -d "$HOME/.dotfiles-backup/install-XXXXXXXX")
    fi
    mv "$HOME/$name" "$backup_dir/$name"
    echo "Backup: $backup_dir/$name"
  fi
done

# Convert only legacy PipeWire links to Stow-owned relative links.
# Keep them functional even if a later Stow conflict stops the script.
for name in 10-wireplumber.conf 20-pipewire-pulse.conf; do
  link="$HOME/.config/pipewire/pipewire.conf.d/$name"
  if [ -L "$link" ]; then
    target=$(readlink "$link")
    case "$name:$target" in
    10-wireplumber.conf:/usr/share/examples/wireplumber/10-wireplumber.conf | \
      20-pipewire-pulse.conf:/usr/share/examples/pipewire/20-pipewire-pulse.conf)
      source="$DOTFILES_DIR/pipewire/.config/pipewire/pipewire.conf.d/$name"
      [ -f "$source" ] || {
        echo "Missing dotfile: $source" >&2
        exit 1
      }
      ln -sfnT "$(realpath --relative-to="${link%/*}" "$source")" "$link"
      ;;
    esac
  fi
done

set --
for package in "$DOTFILES_DIR"/*/; do
  [ -d "$package" ] || continue
  package=${package%/}
  package=${package##*/}
  case "$package" in
  -*)
    echo "Invalid Stow package name: $package" >&2
    exit 1
    ;;
  esac
  set -- "$@" "$package"
done
[ "$#" -gt 0 ] || {
  echo "No Stow packages found." >&2
  exit 1
}
# Conflicting files are reported, not adopted or overwritten.
if stow --simulate --dir="$DOTFILES_DIR" --target="$HOME" "$@" &&
  stow --dir="$DOTFILES_DIR" --target="$HOME" "$@"; then
  :
else
  # A normal conflict should not leave the user's shell defaults missing.
  if [ -n "$backup_dir" ]; then
    for saved in "$backup_dir"/.*; do
      [ -f "$saved" ] || continue
      destination="$HOME/${saved##*/}"
      if [ ! -e "$destination" ] && [ ! -L "$destination" ]; then
        cp -p "$saved" "$destination"
      fi
    done
  fi
  exit 1
fi
ya pkg install

# Install Zed once, rather than updating it every time this script is rerun.
if ! command -v zed >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/zed" ]; then
  zed_installer=$(mktemp)
  trap 'rm -f "$zed_installer"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  curl -fL --retry 3 -o "$zed_installer" https://zed.dev/install.sh
  ZED_CHANNEL=stable sh "$zed_installer"
  rm -f "$zed_installer"
  trap - EXIT INT TERM
fi

echo "Setup complete. Reboot, then log in on tty1 to start Sway."
echo "Check: loginctl session-status; wpctl status; sudo sv status dbus elogind bluetoothd"
