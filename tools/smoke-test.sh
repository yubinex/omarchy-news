#!/usr/bin/env bash
set -euo pipefail
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
mkdir -p /tmp/opencode
test_dir=$(mktemp -d /tmp/opencode/omarchy-news-smoke.XXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
cp "$source_dir/tests/smoke.qml" "$test_dir/shell.qml"
ln -s "$source_dir" "$test_dir/Plugin"
for module in Commons Ui services; do
  ln -s "/usr/share/omarchy/shell/$module" "$test_dir/$module"
done
timeout 10 quickshell -p "$test_dir" --no-color 2>&1 | tee "$test_dir/output.log"
grep -q NEWS_SMOKE_OK "$test_dir/output.log"
if grep -E 'ERROR|WARN scene:|ReferenceError|TypeError' "$test_dir/output.log"; then
  echo 'QML runtime errors detected' >&2
  exit 1
fi
