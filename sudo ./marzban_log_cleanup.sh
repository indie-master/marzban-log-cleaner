#!/bin/bash
# marzban_log_cleanup.sh
# Скрипт для очистки логов Marzban с возможностью резервного копирования.
#
# Использование:
#   1. Для установки (интерактивная настройка и установка задания cron):
#          sudo ./marzban_log_cleanup.sh install
#
#   2. Для вызова меню настройки (для изменения настроек очистки, резервного копирования или немедленной очистки):
#          sudo marzban_log_cleanup.sh log clean
#
#   3. Для выполнения очистки логов (автоматически вызывается заданием cron):
#          sudo ./marzban_log_cleanup.sh
#
# После установки скрипт копируется в /usr/local/bin,
# а конфигурация сохраняется в /etc/marzban_cleanup.conf.
#
# Логи Marzban:
#   Access log: /var/lib/marzban/access.log
#   Error log:  /var/lib/marzban/error.log

# Путь к конфигурационному файлу
CONFIG_FILE="/etc/marzban_cleanup.conf"
# Путь установки скрипта
SCRIPT_PATH="/usr/local/bin/marzban_log_cleanup.sh"

########################################
# Функция установки скрипта
########################################
install_script() {
    echo "=== Установка скрипта очистки логов Marzban ==="
    
    # Запрос частоты очистки (в часах)
    read -p "Введите частоту очистки логов (в часах, например 12): " clean_interval
    clean_interval=${clean_interval:-12}
    
    # Запрос на резервное копирование
    read -p "Создавать резервную копию логов перед очисткой? (Y/n): " backup_response
    backup_response=${backup_response:-Y}
    backup_response=$(echo "$backup_response" | tr '[:upper:]' '[:lower:]')
    if [[ "$backup_response" == "y" || "$backup_response" == "yes" ]]; then
        backup_enabled="yes"
        read -p "Укажите каталог для резервного копирования логов (например, /var/lib/marzban/backup): " backup_dir
        backup_dir=${backup_dir:-/var/lib/marzban/backup}
    else
        backup_enabled="no"
        backup_dir=""
    fi

    echo "Создание конфигурационного файла $CONFIG_FILE..."
    sudo bash -c "cat > $CONFIG_FILE" <<EOF
# Конфигурационный файл для скрипта очистки логов Marzban
ACCESS_LOG="/var/lib/marzban/access.log"
ERROR_LOG="/var/lib/marzban/error.log"
CLEAN_INTERVAL="$clean_interval"
BACKUP_ENABLED="$backup_enabled"
BACKUP_DIR="$backup_dir"
EOF
    echo "Конфигурационный файл создан: $CONFIG_FILE"

    # Копирование скрипта в /usr/local/bin, если он ещё не там
    if [ "$(realpath "$0")" != "$(realpath "$SCRIPT_PATH")" ]; then
        echo "Копирование скрипта в $SCRIPT_PATH..."
        sudo cp "$0" "$SCRIPT_PATH"
        sudo chmod +x "$SCRIPT_PATH"
    fi

    # Настройка задания cron с использованием заданной частоты
    update_cron_job "$clean_interval"

    echo "Установка скрипта завершена."
}

########################################
# Функция обновления задания cron
########################################
update_cron_job() {
    local interval="$1"
    # Формирование cron-задания – запуск в ноль минут каждого часа, кратного interval.
    local new_cron="0 */$interval * * * $SCRIPT_PATH >> /var/log/marzban_cleanup.log 2>&1"
    echo "Обновление задания cron..."
    # Удаляем старые задания, содержащие SCRIPT_PATH, из crontab пользователя root
    (sudo crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH") | sudo crontab -
    # Добавляем новое задание
    (sudo crontab -l 2>/dev/null; echo "$new_cron") | sudo crontab -
    echo "Задание cron установлено: $new_cron"
}

########################################
# Функция очистки логов (резервное копирование + обнуление)
########################################
cleanup_logs() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Ошибка: конфигурационный файл $CONFIG_FILE не найден."
        echo "Пожалуйста, выполните установку: sudo $SCRIPT_PATH install"
        exit 1
    fi

    source "$CONFIG_FILE"
    timestamp=$(date +"%Y%m%d_%H%M%S")

    process_log() {
        local log_file="$1"
        local log_name
        log_name=$(basename "$log_file")
        if [ -f "$log_file" ]; then
            # Резервное копирование, если включено
            if [ "$BACKUP_ENABLED" == "yes" ]; then
                if [ -z "$BACKUP_DIR" ]; then
                    echo "Ошибка: BACKUP_DIR не задан, но резервное копирование включено."
                else
                    sudo mkdir -p "$BACKUP_DIR"
                    backup_file="$BACKUP_DIR/${log_name}_$timestamp"
                    sudo cp "$log_file" "$backup_file"
                    echo "$(date): Лог $log_file скопирован в $backup_file."
                fi
            fi
            # Очистка файла (truncate позволяет сохранить открытые дескрипторы)
            sudo truncate -s 0 "$log_file"
            echo "$(date): Лог $log_file очищен."
        else
            echo "$(date): Лог $log_file не найден."
        fi
    }

    process_log "$ACCESS_LOG"
    process_log "$ERROR_LOG"
}

########################################
# Функция интерактивного меню для настройки и управления
########################################
menu_script() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Конфигурационный файл $CONFIG_FILE не найден."
        echo "Сначала выполните установку: sudo $SCRIPT_PATH install"
        exit 1
    fi

    while true; do
        echo "=== Меню настройки очистки логов Marzban ==="
        echo "1) Показать текущие настройки"
        echo "2) Изменить частоту очистки логов"
        echo "3) Включить/отключить резервное копирование"
        echo "4) Изменить каталог для резервного копирования"
        echo "5) Выполнить очистку логов сейчас"
        echo "6) Выход"
        read -p "Выберите опцию [1-6]: " choice
        case $choice in
            1)
                echo "Текущие настройки:"
                cat "$CONFIG_FILE"
                ;;
            2)
                read -p "Введите новую частоту очистки логов (в часах): " new_interval
                if [ -z "$new_interval" ]; then
                    echo "Неверное значение, частота не изменена."
                else
                    sudo sed -i "s/^CLEAN_INTERVAL=.*/CLEAN_INTERVAL=\"$new_interval\"/" "$CONFIG_FILE"
                    echo "Частота обновлена. Обновляем задание cron..."
                    update_cron_job "$new_interval"
                fi
                ;;
            3)
                read -p "Включить резервное копирование? (Y/n): " backup_resp
                backup_resp=${backup_resp:-Y}
                backup_resp=$(echo "$backup_resp" | tr '[:upper:]' '[:lower:]')
                if [[ "$backup_resp" == "y" || "$backup_resp" == "yes" ]]; then
                    sudo sed -i "s/^BACKUP_ENABLED=.*/BACKUP_ENABLED=\"yes\"/" "$CONFIG_FILE"
                    echo "Резервное копирование включено."
                else
                    sudo sed -i "s/^BACKUP_ENABLED=.*/BACKUP_ENABLED=\"no\"/" "$CONFIG_FILE"
                    echo "Резервное копирование отключено."
                fi
                ;;
            4)
                read -p "Введите новый каталог для резервного копирования: " new_backup_dir
                sudo sed -i "s|^BACKUP_DIR=.*|BACKUP_DIR=\"$new_backup_dir\"|" "$CONFIG_FILE"
                echo "Каталог резервного копирования обновлён."
                ;;
            5)
                echo "Выполняется очистка логов по требованию..."
                cleanup_logs
                echo "Очистка завершена."
                ;;
            6)
                echo "Выход из меню."
                break
                ;;
            *)
                echo "Неверный выбор, попробуйте ещё раз."
                ;;
        esac
        echo ""
    done
}

########################################
# Основной блок обработки аргументов
########################################
case "$1" in
    install)
        install_script
        ;;
    log)
        if [ "$2" == "clean" ]; then
            menu_script
        else
            echo "Неизвестная команда. Используйте: $SCRIPT_PATH log clean"
        fi
        ;;
    *)
        cleanup_logs
        ;;
esac
