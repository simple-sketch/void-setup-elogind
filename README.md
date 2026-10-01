# Void Linux Sway + Noctalia (elogind)

Installer scripts for setting up a Void Linux Sway desktop with Noctalia,
PipeWire, elogind, and Intel graphics support.

The main installer is intended for x86_64 glibc systems with an Intel GPU. It
also clones [dotfiles-stow](https://github.com/simple-sketch/dotfiles-stow) to
`~/dotfiles-stow` and uses GNU Stow to link the desktop configuration.

## Requirements

- Void Linux with working networking
- A normal user with `sudo`
- Intel GPU

## Install

Run as your normal user:

```sh
./install.sh
sudo reboot
```

The installer can be rerun if a download fails.

## Wi-Fi

By default, the installer will not interrupt an active `wpa_supplicant`
connection. If `wpa_supplicant` is enabled, finish the install first, then switch
to iwd manually:

```sh
sudo sv -w 15 stop wpa_supplicant
sudo rm /var/service/wpa_supplicant
sudo ln -s /etc/sv/iwd /var/service/iwd
until sudo sv status iwd >/dev/null 2>&1; do sleep 1; done
sudo sv up iwd
sudo iwctl
```

Only force the switch during install if Ethernet is available or iwd is already
configured:

```sh
IWD_SWITCH=force ./install.sh
```

## Check services

After reboot:

```sh
sudo sv status dbus elogind polkitd socklog-unix nanoklogd dhcpcd tlp tlp-pd
sudo tlp-stat -s
loginctl session-status
wpctl status
```

Group changes take effect after logging in again.

## Optional

```sh
./install_fonts.sh            # fonts
./flatpak_flathub_install.sh  # Flathub apps
```
