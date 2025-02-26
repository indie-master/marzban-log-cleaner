#!/bin/bash

set -e

REPO_URL="https://github.com/indie-master/marzban-log-cleaner/releases/download/v0.1.1/marzban_log_cleanup.sh"
INSTALL_PATH="/usr/local/bin/marzban_log_cleanup.sh"
CONFIG_FILE="/etc/marzban_cleanup.conf"

echo "=== Установка Marzban Log Cleaner ==="

# Проверка, запущен ли скрипт с правами root
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Скрипт должен выполняться с правами root! Используйте sudo."
    exit 1
fi

# Скачивание последней версии
echo "📥 Скачивание последней версии..."
curl -L -o "$INSTALL_PATH" "$REPO_URL"

# Установка прав на выполнение
echo "🔧 Установка прав на выполнение..."
chmod +x "$INSTALL_PATH"

# Создание конфигурационного файла (если его нет)
if [ ! -f "$CONFIG_FILE" ]; then
    echo "📝 Создание конфигурационного файла..."
    cat > "$CONFIG_FILE" <<EOF
# Конфигурация очистки логов Marzban
ACCESS_LOG="/var/lib/marzban/access.log"
ERROR_LOG="/var/lib/marzban/error.log"
CLEAN_INTERVAL="12"
BACKUP_ENABLED="no"
BACKUP_DIR="/var/lib/marzban/backup"
EOF
fi

# Настройка cron (очистка каждые 12 часов по умолчанию)
echo "⏳ Настройка cron..."
(crontab -l 2>/dev/null | grep -v "$INSTALL_PATH"; echo "0 */12 * * * $INSTALL_PATH") | crontab -

echo "✅ Установка завершена!"
echo "📌 Использование:"
echo "  - Изменить настройки: sudo marzban_log_cleanup.sh log clean"
echo "  - Запустить очистку: sudo marzban_log_cleanup.sh"
