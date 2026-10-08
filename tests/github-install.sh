#!/bin/bash
# Real install only on a disposable GitHub-hosted VM. Never run on the production host.
set -euo pipefail
umask 077
if [[ "$EUID" != 0 || "${GITHUB_ACTIONS:-}" != true || "${RUNNER_ENVIRONMENT:-}" != github-hosted ]]; then
  echo 'This test requires a disposable GitHub-hosted runner.' >&2
  exit 1
fi
if [[ -e /etc/sing-box || -e /etc/systemd/system/sing-box.service || -e /lib/systemd/system/sing-box.service ]]; then
  echo 'Refusing to replace an existing installation.' >&2
  exit 1
fi
SOURCE=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
PRIVATE=$(mktemp -d /tmp/sb-ci.XXXXXXXX)
PHASE=prepare
cleanup() {
  local result=$?
  if [ "$result" != 0 ]; then
    printf 'FAIL: %s (private configuration and install logs are not published)\n' "$PHASE" >&2
  fi
  rm -rf -- "$PRIVATE"
}
trap cleanup EXIT
# Remove the runner's preinstalled jq to exercise actual package installation.
# This is guarded above and must never be executed on a user's machine.
apt-get remove -y jq > "$PRIVATE/packages.log" 2>&1
if command -v jq >/dev/null 2>&1; then
  echo 'Unexpected jq outside the system package; cannot exercise missing dependency.' >&2
  exit 1
fi
PHASE=fresh-install
echo 'Testing real dependency installation, verified release download, and systemd startup...'
timeout 900 bash "$SOURCE/install-local.sh" --SERVER_IP 127.0.0.1 --START_PORT 58881 > "$PRIVATE/install.log" 2>&1
PHASE=validate-install
test -x /etc/sing-box/jq
/etc/sing-box/jq --version
/etc/sing-box/sing-box check -C /etc/sing-box/conf > "$PRIVATE/check.log" 2>&1
systemctl is-active --quiet sing-box
systemctl is-enabled --quiet sing-box
ss -H -lnt 'sport = :58881' | grep -q .
ss -H -lnu 'sport = :58882' | grep -q .
test -x /usr/bin/sb
/usr/bin/sb --check > "$PRIVATE/shortcut.log" 2>&1
test "$(/etc/sing-box/jq '[.outbounds[] | select(.type=="vless" or .type=="hysteria2")] | length' /etc/sing-box/subscribe/sing-box)" = 2
! find /etc/sing-box/conf /etc/sing-box/cert /etc/sing-box/subscribe -type f -perm /077 | grep -q .
find /etc/sing-box/conf /etc/sing-box/cert -type f -exec sha256sum {} + > "$PRIVATE/before.sha256"
PID_BEFORE=$(systemctl show sing-box -p MainPID --value)
test "$PID_BEFORE" -gt 0
PHASE=repair-local-jq
rm /etc/sing-box/jq
timeout 180 bash "$SOURCE/install-local.sh" > "$PRIVATE/repair.log" 2>&1
test -x /etc/sing-box/jq
sha256sum --status -c "$PRIVATE/before.sha256"
test "$(systemctl show sing-box -p MainPID --value)" = "$PID_BEFORE"
PHASE=duplicate-install-protection
if timeout 60 bash "$SOURCE/sing-box.sh" --install --SERVER_IP 127.0.0.1 > "$PRIVATE/duplicate.log" 2>&1; then
  echo 'Duplicate installation unexpectedly succeeded.' >&2
  exit 1
fi
sha256sum --status -c "$PRIVATE/before.sha256"
systemctl is-active --quiet sing-box
test "$(systemctl show sing-box -p MainPID --value)" = "$PID_BEFORE"
echo 'PASS: real install, TCP/UDP listeners, jq repair without restart, duplicate-install protection.'
