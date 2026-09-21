# Void Linux Sway + Noctalia (elogind)

These scripts turn a plain Void Linux installation into an Intel Sway desktop
with Noctalia, PipeWire, and elogind. The main installer targets x86_64 glibc:
it enables multilib repositories and installs Intel graphics packages.

The desktop configuration lives in
[dotfiles-stow](https://github.com/simple-sketch/dotfiles-stow). The installer
clones that repository to `~/dotfiles-stow` and uses GNU Stow to symlink its
packages into the home directory.

## Prerequisites

- A working Void Linux network connection
- A normal user with configured `sudo` access
- An Intel GPU

Run the installer as your normal user, not directly as root:

```sh
./install.sh
sudo reboot
```

The installer is safe to rerun after a failed download. It starts the core
D-Bus, elogind, polkit, and socklog services before installing the desktop and
stowing user configuration, so a later failure does not leave those services
merely installed but disabled. TLP starts in its power-saver profile on every
boot; the desktop can still select another profile for the current session.

## Wi-Fi migration

The default `IWD_SWITCH=auto` mode will not disconnect an enabled
`wpa_supplicant` service. It installs iwd and keeps the existing connection;
you can migrate after the rest of the setup succeeds:

```sh
sudo sv -w 15 stop wpa_supplicant
sudo rm /var/service/wpa_supplicant
sudo ln -s /etc/sv/iwd /var/service/iwd
until sudo sv status iwd >/dev/null 2>&1; do sleep 1; done
sudo sv up iwd
sudo iwctl
```

This deliberately interrupts Wi-Fi only after installation is complete. Inside
`iwctl`, list devices and networks, then connect. The saved iwd profile will
reconnect on later boots, while dhcpcd obtains the IP address. If
`wpa_supplicant` is not enabled, the installer enables iwd automatically.

To force the handoff during installation, use the following only when Ethernet
is available or an iwd profile is already provisioned in `/var/lib/iwd`:

```sh
IWD_SWITCH=force ./install.sh
```

## Service checks

After installation (and preferably after reboot), verify the system with:

```sh
sudo sv status dbus elogind polkitd socklog-unix nanoklogd dhcpcd tlp tlp-pd
sudo tlp-stat -s
loginctl session-status
wpctl status
```

Group changes for `socklog`, `video`, and `bluetooth` take effect at the next
login. The installer also warns about dangling links under `/var/service`.

## Optional installs

```sh
./flatpak_flathub_install.sh  # Flathub, Keypunch, DBeaver, and Postman
```
