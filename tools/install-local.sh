#!/usr/bin/env bash
set -euo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
plugin_dir="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/yubinex.omarchy-news"
shell_config="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json"

if [[ -e "$plugin_dir" || -L "$plugin_dir" ]]; then
  if [[ $(readlink -f -- "$plugin_dir") != "$source_dir" ]]; then
    echo "Refusing to overwrite existing plugin: $plugin_dir" >&2
    exit 1
  fi
else
  mkdir -p -- "$(dirname -- "$plugin_dir")"
  ln -s -- "$source_dir" "$plugin_dir"
fi

if [[ -f "$shell_config" ]]; then
  cp -p -- "$shell_config" "$shell_config.before-omarchy-news.$(date +%Y%m%d-%H%M%S).bak"
fi
omarchy-shell shell rescanPlugins
omarchy bar put yubinex.omarchy-news --section right
echo "Installed local development link: $plugin_dir -> $source_dir"
