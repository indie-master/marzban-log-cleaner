#!/bin/bash
set -euo pipefail

# Legacy compatibility wrapper. The maintained CLI is /usr/local/bin/marzban-log.
if command -v marzban-log >/dev/null 2>&1; then
    CLI="$(command -v marzban-log)"
elif [ -x "./marzban-log" ]; then
    CLI="./marzban-log"
else
    echo "marzban-log не найден. Установите проект через: sudo ./install.sh" >&2
    exit 1
fi

case "${1:-clean}" in
    install)
        exec "$CLI" install
        ;;
    log)
        if [ "${2:-}" = "clean" ]; then
            exec "$CLI" clean
        fi
        echo "Неизвестная legacy-команда. Используйте: marzban-log clean" >&2
        exit 1
        ;;
    *)
        exec "$CLI" "$@"
        ;;
esac
