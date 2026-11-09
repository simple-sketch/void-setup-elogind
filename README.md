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

## Simplified installer

For a smaller, straightforward version of the full desktop setup:

```sh
./install-simple.sh
sudo reboot
```

Run as your normal user, **not** with `sudo`. The original `install.sh` is
unchanged. Both scripts target the same Intel / x86_64 glibc desktop.

The simplified script installs the same desktop packages, configures ALSA and
a default TLP profile, starts the runit services, clones/stows the dotfiles,
installs Yazi plugins, and installs Zed if missing. It updates the system and
asks you to trust the UniversalRepository key on first use; check the printed
fingerprint before accepting.

Reruns reuse installed packages and the existing dotfiles checkout (without
pulling or discarding local edits). Existing TLP settings are kept. Regular
shell/editor defaults are backed up under `~/.dotfiles-backup/`; other Stow
conflicts stop the script rather than overwrite your files. It has no automatic
rollback: fix a reported problem and rerun, or restore the printed backup.

An existing network service is left alone; there is no forced Wi-Fi switch.
PipeWire runs in the user session through the dotfiles, not as a system service.
The optional fonts and Flatpak scripts remain separate.

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

The login profile launches `dbus-run-session sway`. Sway's config starts
`~/.config/sway/scripts/start-audio.sh`, which stops audio when Sway exits.
The `pipewire` Stow package owns the WirePlumber and pipewire-pulse drop-ins;
the installer migrates its old example-file links to that package without
replacing unrelated configuration.

Do not run a separate PulseAudio server alongside PipeWire. Reboot once
after updating an old setup.

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
