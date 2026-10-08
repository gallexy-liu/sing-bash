#!/bin/bash
# Lightweight test: private directories, existing sing-box binary, no container/service/firewall changes.
set -e
umask 077
[ "$EUID" = 0 ] || exit 1
SOURCE=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
TEST_DIR=$(mktemp -d /tmp/sb-fresh-config.XXXXXXXX)
awk '/^check_cdn$/{exit} {print}' "$SOURCE/sing-box.sh" > "$TEST_DIR/functions.sh"
set +e
source "$TEST_DIR/functions.sh"
set -e
trap 'rm -rf -- "$TEMP_DIR" "$TEST_DIR"' EXIT
SCRIPT_DIR=$SOURCE
WORK_DIR="$TEST_DIR/work"
SUBSCRIBE_TEMPLATE="$SOURCE/templates"
SINGBOX_DAEMON_FILE="$TEST_DIR/sing-box.service"
ARGO_DAEMON_FILE="$TEST_DIR/argo.service"
FIREWALL_STATE_DIR="$WORK_DIR/firewall"
SERVICE_FIREWALL_STATE_FILE="$FIREWALL_STATE_DIR/service_ports.list"
mkdir -p "$WORK_DIR" "$TEST_DIR/bin"
PATH="$TEST_DIR/bin:$PATH"
L=C
SYSTEM=Ubuntu
# Simulate the package-manager boundary; never install packages on the production host.
install_system_packages() {
  printf '%s\n' "$@" > "$TEST_DIR/packages"
  ln -sf /etc/sing-box/jq "$TEST_DIR/bin/jq"
}
systemctl() { return 1; }
check_dependencies > "$TEST_DIR/deps.log" 2>&1
[ -x "$WORK_DIR/jq" ]
"$WORK_DIR/jq" --version >/dev/null
# Replace only environment-mutating boundaries; run the real variable/config/cert/export logic.
prepare_install_binaries() { ln -s /etc/sing-box/sing-box "$TEMP_DIR/sing-box"; }
install() {
  if [ "${*: -1}" = "$WORK_DIR/sing-box" ]; then
    ln -s /etc/sing-box/sing-box "$WORK_DIR/sing-box"
  else
    command install "$@"
  fi
}
systemctl() { return 0; }
cmd_systemctl() { return 0; }
sync_firewall_rules() { :; }
ensure_stats_data() { return 1; }
ping() { return 1; }
ping6() { return 1; }
IS_TUN=is_tun
IS_PREFER_GO=true
IS_BRUTAL=false
IS_SUB=no_sub
IS_ARGO=no_argo
NONINTERACTIVE_INSTALL=noninteractive_install
CHOOSE_PROTOCOLS=bc
# The real CI installation is still listening on 58881/58882.
# Pick an unused pair for configuration-only validation, without starting a service.
START_PORT=58891
while is_port_in_use "$START_PORT" || is_port_in_use "$((START_PORT + 1))"; do
  START_PORT=$((START_PORT + 2))
  [ "$START_PORT" -lt 59091 ] || { echo 'FAIL: no free test port pair'; exit 1; }
done
SERVER_IP=127.0.0.1
check_arch
# Upstream interactive helpers intentionally use nonzero statuses; don't add global errexit to them.
set +e
(install_sing-box && export_list install) > "$TEST_DIR/install.log" 2>&1
RESULT=$?
set -e
[ "$RESULT" = 0 ] || { printf 'FAIL: fresh config generation (private log suppressed)\n'; exit 1; }
/etc/sing-box/sing-box check -C "$WORK_DIR/conf" >/dev/null 2>&1
[ "$(find "$WORK_DIR/conf" -name '*_inbounds.json' | wc -l)" -eq 2 ]
! grep -Rqs '"warp-ep"' "$WORK_DIR/conf"
"$WORK_DIR/jq" -e '[.outbounds[] | select(.type=="vless" or .type=="hysteria2")] | length==2' "$WORK_DIR/subscribe/sing-box" >/dev/null
[ -s "$SINGBOX_DAEMON_FILE" ]
! find "$WORK_DIR/conf" "$WORK_DIR/cert" "$WORK_DIR/subscribe" -type f -perm /077 | grep -q .
find "$WORK_DIR/conf" "$WORK_DIR/cert" -type f -exec sha256sum {} + > "$TEST_DIR/before.sha256"
if (install_sing-box) > /dev/null 2>&1; then echo 'FAIL: duplicate install accepted'; exit 1; fi
sha256sum --status -c "$TEST_DIR/before.sha256"
printf 'PASS: missing-jq preparation, fresh Reality/Hysteria2 config+cert+exports, TUN without WARP, duplicate-install protection.\n'
