#!/bin/bash
# Root-owned local launcher; no remote code and no inherited shell hooks.
[ "$EUID" -eq 0 ] || { printf '请使用 sudo sb\n' >&2; exit 1; }
exec /usr/bin/env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin HOME=/root LANG=C.UTF-8 TERM="${TERM:-dumb}" \
  /usr/bin/flock /etc/sing-box/local/.management.lock \
  /bin/bash /etc/sing-box/local-bash/sing-box.sh "$@"
