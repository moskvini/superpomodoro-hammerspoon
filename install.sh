#!/usr/bin/env bash
set -euo pipefail

source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_dir="${HOME}/.hammerspoon"
target="${config_dir}/init.lua"

mkdir -p "${config_dir}"

if [[ -f "${target}" ]]; then
  backup="${target}.backup.$(date +%Y%m%d-%H%M%S)"
  cp "${target}" "${backup}"
  echo "Backed up existing config to ${backup}"
fi

cp "${source_dir}/init.lua" "${target}"
echo "Installed ${target}"

if command -v hs >/dev/null 2>&1; then
  hs -n -t 4 -c 'hs.reload()' >/dev/null 2>&1 || true
else
  open -a Hammerspoon >/dev/null 2>&1 || true
fi

echo "Done. Open Hammerspoon and allow Accessibility, Automation, and Notifications when macOS asks."
