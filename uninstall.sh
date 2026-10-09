#!/usr/bin/env bash
# Removes what install.sh put in place. Your lighting profiles (~/.config/awcc/config.json) are kept unless you pass --purge.
# Usage: ./uninstall.sh [--dry-run] [--yes] [--purge] [--no-udev] [--no-service]
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
dry=0; yes=0; purge=0; udev=1; service=1
for a in "$@"; do case "$a" in --dry-run) dry=1 ;; --yes) yes=1 ;; --purge) purge=1 ;; --no-udev) udev=0 ;; --no-service) service=0 ;; -h|--help) sed -n 2,4p "$0"; exit 0 ;; *) echo "unknown option: $a" >&2; exit 2 ;; esac; done
id=$(python3 -c "import json; print(json.load(open('$here/manifest.json'))['id'])")
ask() { [ "$yes" = 1 ] && return 0; read -r -p "$1 [y/N] " r; [[ "$r" =~ ^[Yy] ]]; }
do_() { if [ "$dry" = 1 ]; then echo "  (dry run) $*"; else "$@"; fi; }

cfg="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json"
if [ -f "$cfg" ] && grep -q "\"$id\"" "$cfg"; then
  echo "note: $cfg still lists the widget \"$id\". Delete that entry (an object with \"id\": \"$id\" under bar.layout) yourself; this script never edits your bar layout."
fi
echo "Removing the bar widget files"
do_ rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$id"
if [ "$service" = 1 ]; then
  echo "Stopping the user service"
  do_ systemctl --user disable --now awcc.service 2>/dev/null || true
  do_ rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/awcc.service"
  do_ systemctl --user daemon-reload 2>/dev/null || true
fi
do_ rm -f "$HOME/.local/bin/awcc"
if [ "$udev" = 1 ] && [ -e /etc/udev/rules.d/70-awcc.rules ] && ask "Remove /etc/udev/rules.d/70-awcc.rules with pkexec?"; then
  do_ pkexec sh -c "rm -f /etc/udev/rules.d/70-awcc.rules && udevadm control --reload-rules"
fi
if [ "$purge" = 1 ]; then do_ rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/awcc"; else echo "kept ~/.config/awcc (use --purge to delete it)"; fi
echo "Removed. If you added Hyprland key bindings for awcc, delete them from your bindings file yourself."
