#!/usr/bin/env bash
set -euo pipefail

DISK_LIMIT=80
FAILED=0
if (($#)); then TARGETS=("$@"); else TARGETS=(https://google.com); fi

ok() { echo -e "\e[32m[OK]\e[0m $*"; }
warn() { echo -e "\e[33m[WARN]\e[0m $*"; }
fail() {
  echo -e "\e[31m[FAIL]\e[0m $*"
  FAILED=1
}

echo "== $(hostname) | $(date -Is) =="

cores=$(nproc)
load=$(cut -d' ' -f1 /proc/loadavg)
if awk -v l="$load" -v c="$cores" 'BEGIN{exit !(l<c)}'; then ok "load $load / $cores cores"; else warn "load $load / $cores cores"; fi

mem=$(free | awk '/Mem:/{printf "%d", $3/$2*100}')
if ((mem < 90)); then ok "RAM ${mem}%"; else warn "RAM ${mem}%"; fi

while read -r use mnt; do
  if ((${use%\%} < DISK_LIMIT)); then ok "disk $mnt $use"; else fail "disk $mnt $use"; fi
done < <(df --output=pcent,target -x tmpfs -x devtmpfs -x overlay -x efivarfs | tail -n +2)

echo "-- listening TCP --"
ss -tlnH | awk '{print "  " $4}'

for url in "${TARGETS[@]}"; do
    host=$(awk -F/ '{print $3}' <<<"$url")
    host=${host%%:*}
  if ! getent hosts "$host" >/dev/null; then
    fail "DNS $host"
    continue
  fi
  ok "DNS $host"
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$url" || echo true)
  if [[ $code =~ ^[23] ]]; then ok "HTTP $url -> $code"; else fail "HTTP $url -> $code"; fi
done

exit $FAILED
