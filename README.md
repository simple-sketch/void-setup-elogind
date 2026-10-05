# Void Linux · Sway + Noctalia

Sets up an Intel desktop with Sway, Noctalia, elogind, PipeWire, Bluetooth,
and iwd. Clones [dotfiles-stow](https://github.com/simple-sketch/dotfiles-stow)
to `~/dotfiles-stow` and links the configuration with GNU Stow.

## Install

Requires **Void Linux x86_64 glibc**, an Intel GPU, working networking,
and a normal user with `sudo`. Do not combine this setup with seatd or turnstile.

Run as your normal user:

```sh
./install.sh
sudo reboot
```

Log in on **tty1** to start Sway automatically. The installer can be rerun
if a download fails.

## Wi-Fi

An enabled `wpa_supplicant` is left running to avoid dropping your connection.
To switch to iwd afterward, use Ethernet or be prepared to reconnect:

```sh
sudo sv -w 15 stop wpa_supplicant
sudo rm /var/service/wpa_supplicant
sudo ln -s /etc/sv/iwd /var/service/iwd
until sudo sv status iwd >/dev/null 2>&1; do sleep 1; done
sudo sv up iwd
sudo iwctl
```

To switch during installation instead, use `IWD_SWITCH=force ./install.sh`
only with Ethernet available or iwd already configured.

## Sound and Bluetooth

Use Noctalia's panels to pair Bluetooth devices and select audio outputs.
For music, choose the headset's A2DP profile when available.

PipeWire starts with Sway and stops on logout. Do not run a separate
PulseAudio server alongside it. Reboot once after updating an old setup.

## Checks

```sh
sudo sv status dbus elogind bluetoothd
loginctl session-status
wpctl status
bluetoothctl show
```

Sway startup logs: `~/.local/state/sway.log`. System logs: `svlogtail`.

## Optional

```sh
./install_fonts.sh            # fonts
./flatpak_flathub_install.sh  # Flathub apps
```
