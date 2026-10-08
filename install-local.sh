#!/bin/bash
# Install sing-box on a fresh machine, or deploy this local manager over an existing installation.
# Backs up management files only; does not change server conf/cert or reload service.
set -euo pipefail
umask 077
[ "$EUID" = 0 ] || { printf '请使用 sudo bash install-local.sh\n' >&2; exit 1; }
HERE=$(cd -- "$(dirname -- "$0")" && pwd -P)
ROOT=/etc/sing-box
if [ ! -x "$ROOT/sing-box" ] || [ ! -d "$ROOT/conf" ]; then
  exec /bin/bash "$HERE/sing-box.sh" --install "$@"
fi
if [ ! -x "$ROOT/jq" ] || ! command -v flock >/dev/null 2>&1; then
  /bin/bash "$HERE/sing-box.sh" --prepare-dependencies
fi
command -v flock >/dev/null
bash -n "$HERE/sing-box.sh"
bash -n "$HERE/sb.sh"
"$ROOT/sing-box" check -C "$ROOT/conf" >/dev/null 2>&1
install -d -m 700 "$ROOT/local"
exec 9> "$ROOT/local/.management.lock"
flock -x 9
BACKUP=$(mktemp -d /var/backups/sing-box-bash.XXXXXXXX)
[ ! -e "$ROOT/sb.sh" ] || cp -a "$ROOT/sb.sh" "$BACKUP/sb.sh"
[ ! -e "$ROOT/local-bash" ] || cp -a "$ROOT/local-bash" "$BACKUP/local-bash"
STAGE=$(mktemp -d "$ROOT/.bash-stage.XXXXXXXX")
rollback() {
  local status=$?
  rm -rf -- "$STAGE"
  if [ "$status" != 0 ]; then
    [ ! -e "$BACKUP/sb.sh" ] || cp -a "$BACKUP/sb.sh" "$ROOT/sb.sh"
    if [ -e "$BACKUP/local-bash" ]; then
      rm -rf -- "$ROOT/local-bash"
      cp -a "$BACKUP/local-bash" "$ROOT/local-bash"
    fi
    printf '安装失败；原入口已恢复。备份：%s\n' "$BACKUP" >&2
  fi
}
trap rollback EXIT
install -m 600 "$HERE/sing-box.sh" "$HERE/sb.sh" "$HERE/install-local.sh" "$HERE/LICENSE" "$HERE/upstream.json" "$HERE/README.md" "$STAGE/"
install -d -m 700 "$STAGE/templates"
install -m 600 "$HERE/templates/"* "$STAGE/templates/"
[ ! -e "$ROOT/local-bash" ] || mv "$ROOT/local-bash" "$BACKUP/replaced-local-bash"
mv "$STAGE" "$ROOT/local-bash"
install -m 700 "$HERE/sb.sh" "$ROOT/.sb-bash-new"
mv -f "$ROOT/.sb-bash-new" "$ROOT/sb.sh"
ln -sfn "$ROOT/sb.sh" /usr/bin/sb
printf '已安装本地 Bash 入口，未重启服务。管理文件备份：%s\n' "$BACKUP"
