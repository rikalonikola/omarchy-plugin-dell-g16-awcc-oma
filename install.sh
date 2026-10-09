#!/usr/bin/env bash
# Installs the Dell G16 AWCC-Oma plugin for the current user. Nothing is changed without being listed first:
#   1. ~/.local/bin/awcc                         the command-line tool the bar widget talks to
#   2. ~/.config/systemd/user/awcc.service       restores keyboard lighting at login, switches profile on AC/battery (enabled only if you say yes)
#   3. ~/.config/omarchy/plugins/<plugin id>/    the bar widget (manifest.json + BarWidget.qml)
#   4. /etc/udev/rules.d/70-awcc.rules           (needs root through pkexec, asks first) lets your user write the thermal profile, the fan
#                                                boost and the keyboard-lighting USB device without sudo
# It never edits ~/.config/omarchy/shell.json, your Hyprland bindings or any existing awcc config.
# Usage: ./install.sh [--dry-run] [--yes] [--no-udev] [--no-service] [--force]
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
dry=0; yes=0; udev=1; service=1; force=0
for a in "$@"; do case "$a" in
  --dry-run) dry=1 ;; --yes) yes=1 ;; --no-udev) udev=0 ;; --no-service) service=0 ;; --force) force=1 ;;
  -h|--help) sed -n 2,12p "$0"; exit 0 ;; *) echo "unknown option: $a" >&2; exit 2 ;; esac; done

id=$(python3 -c "import json,sys; print(json.load(open('$here/manifest.json'))['id'])")
plugin_dir="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$id"
bin="$HOME/.local/bin/awcc"
unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

ask() { [ "$yes" = 1 ] && return 0; read -r -p "$1 [y/N] " r; [[ "$r" =~ ^[Yy] ]]; }
do_() { if [ "$dry" = 1 ]; then echo "  (dry run) $*"; else "$@"; fi; }

command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 1; }
product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
case "$product" in
  "Dell G16 7630") ;;                                   # the verified model
  "Dell G16 "[0-9][0-9][0-9][0-9])
    echo "note: this is a '$product'. This package is verified on the Dell G16 7630 only; on your revision the keyboard light, fan boost"
    echo "      and G key may behave differently. Hardware writes stay OFF until you run 'awcc doctor' and then 'awcc allow-unverified on'."
    ask "Install anyway?" || exit 1 ;;
  *)
    echo "This package is made for the Dell G16. This machine is '${product:-unknown}', so keyboard light, fans and profiles would stay disabled."
    [ "$force" = 1 ] || { echo "Not installing (use --force to install the read-only sensor view anyway)."; exit 1; } ;;
esac

echo "Installing the command-line tool to $bin"
do_ mkdir -p "$HOME/.local/bin"
[ -e "$bin" ] && [ ! -L "$bin" ] && ! cmp -s "$bin" "$here/bin/awcc" && { ask "$bin already exists and differs. Replace it?" || exit 1; }
do_ install -m 755 "$here/bin/awcc" "$bin"

echo "Installing the bar widget to $plugin_dir"
do_ mkdir -p "$plugin_dir"
do_ install -m 644 "$here/manifest.json" "$here/BarWidget.qml" "$plugin_dir/"

if [ "$service" = 1 ] && ask "Install and start the user service (restores lighting at login, switches profile on AC/battery)?"; then
  do_ mkdir -p "$unit_dir"
  do_ install -m 644 "$here/systemd/awcc.service" "$unit_dir/awcc.service"
  do_ systemctl --user daemon-reload
  do_ systemctl --user enable --now awcc.service
fi

if [ "$udev" = 1 ]; then
  cat <<'TXT'

The udev rules give your user access, without sudo, to exactly three things:
  - the keyboard-lighting USB controller 187c:0551 (uaccess for the logged-in user)
  - /sys/class/platform-profile/*/profile   (group wheel may write)
  - the fan_boost files of the alienware_wmi hwmon (group wheel may write)
TXT
  if ask "Install /etc/udev/rules.d/70-awcc.rules with pkexec (asks for your password)?"; then
    do_ pkexec sh -c "install -m 644 '$here/udev/70-awcc.rules' /etc/udev/rules.d/70-awcc.rules && udevadm control --reload-rules && udevadm trigger --subsystem-match=usb --subsystem-match=platform-profile --subsystem-match=hwmon --action=add && udevadm settle"
  else
    echo "skipped: without the rules awcc needs root to change profiles, fans and lighting."
  fi
fi

cat <<TXT

Done. To show the widget in the bar (nothing was changed in shell.json):
    omarchy bar put $id --section right
To remove everything later: ./uninstall.sh
TXT
