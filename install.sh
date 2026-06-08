#!/bin/bash
set -euo pipefail

SCRIPT_NAME="marzban-log"
REPO_URL="${MARZBAN_LOG_REPO_URL:-https://raw.githubusercontent.com/indie-master/marzban-log-cleaner/main/${SCRIPT_NAME}}"
INSTALL_PATH="${MARZBAN_LOG_INSTALL_PATH:-/usr/local/bin/${SCRIPT_NAME}}"
CONFIG_DIR="${MARZBAN_LOG_CONFIG_DIR:-/etc/marzban-log-cleaner}"
CONFIG_FILE="${MARZBAN_LOG_CONFIG:-${CONFIG_DIR}/config.yml}"
SYSTEMD_DIR="${MARZBAN_LOG_SYSTEMD_DIR:-/etc/systemd/system}"
SERVICE_FILE="${SYSTEMD_DIR}/marzban-log-cleaner.service"
TIMER_FILE="${SYSTEMD_DIR}/marzban-log-cleaner.timer"

backup_if_exists() {
    local path="$1"
    if [ -e "$path" ]; then
        local backup="${path}.bak-$(date +%Y%m%d-%H%M%S)"
        cp -a "$path" "$backup"
        echo "🛟 Backup создан: $backup"
    fi
}

write_default_config() {
    mkdir -p "$CONFIG_DIR"
    if [ -f "$CONFIG_FILE" ]; then
        backup_if_exists "$CONFIG_FILE"
        echo "📝 Существующий конфиг сохранён и не перезаписан: $CONFIG_FILE"
        return
    fi
    cat > "$CONFIG_FILE" <<'EOF'
# Marzban Log Cleaner configuration
# max_age supports minutes/hours/days: 30m, 12h, 7d, 30d
# action: truncate keeps the file inode for running services; delete removes the file completely.
logs:
  - name: marzban-access
    path: /var/lib/marzban/access.log
    max_age: 7d
    action: truncate
    enabled: true

  - name: marzban-error
    path: /var/lib/marzban/error.log
    max_age: 14d
    action: truncate
    enabled: true

  - name: marzban-node-access
    path: /var/lib/marzban-node/access.log
    max_age: 3d
    action: truncate
    enabled: true

  - name: marzban-node-error
    path: /var/lib/marzban-node/error.log
    max_age: 3d
    action: truncate
    enabled: true
EOF
    echo "📝 Создан дефолтный конфиг: $CONFIG_FILE"
}

install_binary() {
    backup_if_exists "$INSTALL_PATH"
    if [ -f "./${SCRIPT_NAME}" ]; then
        cp "./${SCRIPT_NAME}" "$INSTALL_PATH"
    else
        curl -fsSL -o "$INSTALL_PATH" "$REPO_URL"
    fi
    chmod +x "$INSTALL_PATH"
    echo "🔧 Установлен CLI: $INSTALL_PATH"
}

install_systemd() {
    backup_if_exists "$SERVICE_FILE"
    backup_if_exists "$TIMER_FILE"
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Marzban Log Cleaner
Documentation=https://github.com/indie-master/marzban-log-cleaner

[Service]
Type=oneshot
ExecStart=${INSTALL_PATH} clean
EOF
    cat > "$TIMER_FILE" <<EOF
[Unit]
Description=Run Marzban Log Cleaner periodically

[Timer]
OnCalendar=hourly
Persistent=true
Unit=marzban-log-cleaner.service

[Install]
WantedBy=timers.target
EOF
    if [ "${MARZBAN_LOG_SKIP_SYSTEMD_START:-0}" = "1" ]; then
        echo "⚠️ MARZBAN_LOG_SKIP_SYSTEMD_START=1; systemd timer не включался."
    elif command -v systemctl >/dev/null 2>&1; then
        systemctl daemon-reload
        systemctl enable --now marzban-log-cleaner.timer
        echo "⏳ Systemd timer включён: marzban-log-cleaner.timer"
    else
        echo "⚠️ systemctl не найден; unit-файлы записаны, но timer не включён автоматически."
    fi
}

if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Скрипт должен выполняться с правами root. Используйте sudo."
    exit 1
fi

echo "=== Установка Marzban Log Cleaner ==="
install_binary
write_default_config
install_systemd

echo "✅ Установка завершена!"
echo "Команды:"
echo "  marzban-log status"
echo "  marzban-log validate"
echo "  marzban-log clean --dry-run"
echo "  marzban-log add"
echo "  marzban-log edit"
