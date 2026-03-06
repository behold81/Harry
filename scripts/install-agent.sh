#!/usr/bin/env bash
set -euo pipefail

# Harry Agent installer (node-side)
# Usage:
#   export HARRY_BASE_URL="http://<brain-host>:8787"
#   curl -fsSL https://.../install-agent.sh | sudo -E bash

: "${HARRY_BASE_URL:?Set HARRY_BASE_URL, e.g. http://192.168.1.10:8787}"

AGENT_DIR="${HARRY_AGENT_DIR:-/opt/harry/agent}"
AGENT_PATH="${AGENT_DIR}/harry_agent.sh"

mkdir -p "$AGENT_DIR"

curl -fsSL "${HARRY_BASE_URL}/dist/harry_agent.sh" | tee "$AGENT_PATH" >/dev/null
chmod +x "$AGENT_PATH"

# systemd unit + timer
cat > /etc/systemd/system/harry-agent.service <<EOF_UNIT
[Unit]
Description=Harry Agent snapshot sender
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
User=root
Group=root
Environment="HARRY_SELF_UPDATE=1"
Environment="HARRY_BASE_URL=${HARRY_BASE_URL}"
Environment="HARRY_INGEST_URL=${HARRY_BASE_URL}/ingest"
ExecStart=${AGENT_PATH}
SuccessExitStatus=0
EOF_UNIT

cat > /etc/systemd/system/harry-agent.timer <<'EOF_TIMER'
[Unit]
Description=Run Harry Agent every 5 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
AccuracySec=30s
Persistent=true

[Install]
WantedBy=timers.target
EOF_TIMER

systemctl daemon-reload
systemctl enable --now harry-agent.timer

echo "✅ Harry Agent installed."
echo "Timer:  systemctl status harry-agent.timer --no-pager"
echo "Logs:   journalctl -u harry-agent.service --since '15 min ago' --no-pager"
