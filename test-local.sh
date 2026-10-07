#!/bin/bash
# Root-only test using a private snapshot. Does not edit live conf/cert or reload services.
set -e
umask 077
[ "$EUID" = 0 ] || exit 1
HERE=$(cd -- "$(dirname -- "$0")" && pwd -P)
if grep -Eq 'realitykey\.cloudflare|stat\.cloudflare|api\.qrserver|bash <\(|--no-check-certificate|WARP_PRIVATE_KEY="[A-Za-z0-9+/]' "$HERE/sing-box.sh"; then
  printf 'FAIL: prohibited remote-code, telemetry or shared-key pattern\n' >&2
  exit 1
fi
STAGE=$(mktemp -d /run/sb-bash-test.XXXXXXXX)
trap 'rm -rf -- "$STAGE"' EXIT
mkdir "$STAGE/work"
cp -a /etc/sing-box/conf /etc/sing-box/cert /etc/sing-box/subscribe /etc/sing-box/list "$STAGE/work/"
ln -s /etc/sing-box/sing-box "$STAGE/work/sing-box"
ln -s /etc/sing-box/jq "$STAGE/work/jq"
cp "$STAGE/work/subscribe/sing-box" "$STAGE/before.json"
find "$STAGE/work/conf" "$STAGE/work/cert" -type f -exec sha256sum {} + > "$STAGE/before.sha256"
# Only definitions; main menu/argument dispatcher is not evaluated.
awk '/^check_cdn$/{exit} {print}' "$HERE/sing-box.sh" > "$STAGE/functions.sh"
cat > "$STAGE/run.sh" <<'RUN'
#!/bin/bash
source "$1/functions.sh"
WORK_DIR="$1/work"
SUBSCRIBE_TEMPLATE="$2/templates"
L=C
SYSTEM=Ubuntu
SINGBOX_DAEMON_FILE=/etc/systemd/system/sing-box.service
ARGO_DAEMON_FILE=/etc/systemd/system/argo.service
# Service mutation is forbidden in this export test.
cmd_systemctl() { [ "$1" = status ] && command systemctl "$@"; }
eval "$(declare -f check_install | command sed '1s/check_install/original_check_install/')"
check_install() { local WORK_DIR=/etc/sing-box; original_check_install; }
check_arch
check_brutal
export_list
RUN
if ! unshare --net -- bash "$STAGE/run.sh" "$STAGE" "$HERE" > "$STAGE/stdout" 2> "$STAGE/stderr"; then
  printf 'FAIL: export failed (private diagnostics suppressed)\n' >&2
  exit 1
fi
sha256sum --status -c "$STAGE/before.sha256"
/etc/sing-box/jq -S '[.outbounds[] | select(.type == "vless" or .type == "hysteria2" or .type == "anytls")] | sort_by(.tag)' "$STAGE/before.json" > "$STAGE/old-nodes.json"
/etc/sing-box/jq -S '[.outbounds[] | select(.type == "vless" or .type == "hysteria2" or .type == "anytls")] | sort_by(.tag)' "$STAGE/work/subscribe/sing-box" > "$STAGE/new-nodes.json"
cmp -s "$STAGE/old-nodes.json" "$STAGE/new-nodes.json" || { printf 'FAIL: node mismatch (details suppressed)\n'; exit 1; }
/etc/sing-box/sing-box check -C "$STAGE/work/conf" >/dev/null 2>&1
! find "$STAGE/work/subscribe" -type f -perm /077 | grep -q .
! grep -Rq 'api.qrserver.com' "$STAGE/work/subscribe"
printf 'PASS: Bash export succeeds without network; node parameters match; server config/cert unchanged; exports private.\n'
