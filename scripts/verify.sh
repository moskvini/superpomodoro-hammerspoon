#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
init_lua="${repo_dir}/init.lua"

run_hs() {
  hs -n -t 6 -c "$1"
}

echo "==> Checking install script syntax"
bash -n "${repo_dir}/install.sh"

echo "==> Checking init.lua syntax"
run_hs "local f, err = loadfile('${init_lua}'); return tostring(f ~= nil), tostring(err)"

echo "==> Running flowAutoStart.selfTest()"
run_hs "return hs.inspect(flowAutoStart.selfTest())"

echo "==> Checking live status"
run_hs "return hs.inspect(flowAutoStart.status())"

if [[ "${1:-}" == "--lock" ]]; then
  echo "==> Running real lock verification"
  echo "This will lock the screen via hs.caffeinate.lockScreen()."
  run_hs "return flowAutoStart.enterBreakLockMode('manual verification')"
fi

echo "==> Done"
