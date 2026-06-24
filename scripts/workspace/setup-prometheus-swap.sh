#!/usr/bin/env bash
set -euo pipefail

SWAPFILE="${SWAPFILE:-/swapfile-48g}"
SWAP_SIZE="${SWAP_SIZE:-48G}"
ZRAM_CONF_DIR="/etc/systemd/zram-generator.conf.d"
ZRAM_CONF="$ZRAM_CONF_DIR/99-prometheus.conf"
FSTAB_LINE="$SWAPFILE none swap sw,pri=10 0 0"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Run as root, for example: sudo $0"
  exit 1
fi

echo "==> Current memory/swap"
free -h
swapon --show || true
df -hT "$(dirname "$SWAPFILE")"

if swapon --show=NAME --noheadings | grep -Fxq "$SWAPFILE"; then
  echo "==> $SWAPFILE is already active"
else
  if [[ ! -f "$SWAPFILE" ]]; then
    echo "==> Creating $SWAP_SIZE swapfile at $SWAPFILE"
    if ! fallocate -l "$SWAP_SIZE" "$SWAPFILE"; then
      echo "fallocate failed; falling back to dd"
      dd if=/dev/zero of="$SWAPFILE" bs=1M count=49152 status=progress
    fi
  fi
  chmod 600 "$SWAPFILE"
  mkswap -f "$SWAPFILE"
  swapon --priority 10 "$SWAPFILE"
fi

if ! grep -Fqs "$FSTAB_LINE" /etc/fstab; then
  echo "==> Adding swapfile to /etc/fstab"
  printf '%s\n' "$FSTAB_LINE" >> /etc/fstab
else
  echo "==> /etc/fstab already contains $SWAPFILE"
fi

echo "==> Configuring zram0 as 16G, priority 100"
mkdir -p "$ZRAM_CONF_DIR"
cat > "$ZRAM_CONF" <<'EOF'
[zram0]
zram-size = min(ram, 16384)
compression-algorithm = zstd lzo-rle
swap-priority = 100
EOF

systemctl daemon-reload
if systemctl is-active --quiet systemd-zram-setup@zram0.service; then
  swapoff /dev/zram0 || true
fi
systemctl restart systemd-zram-setup@zram0.service

echo "==> Result"
free -h
swapon --show
zramctl || true
