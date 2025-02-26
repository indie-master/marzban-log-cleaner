# Marzban Log Cleaner

Скрипт для очистки логов Marzban с удобным CLI.

## 📌 Возможности
- Очистка логов вручную или по расписанию.
- Возможность резервного копирования перед очисткой.
- Настраиваемая частота очистки (через `cron`).
- Удобное управление через `marzban-log`.

## 🔧 Установка
```bash
curl -L https://raw.githubusercontent.com/indie-master/marzban-log-cleaner/main/marzban-log -o /usr/local/bin/marzban-log
chmod +x /usr/local/bin/marzban-log
marzban-log install
```

## 🛠 Использование
```
marzban-log
```
— показать список команд.
```
marzban-log clean
```
— очистка логов.
marzban-log update — обновление скрипта.
marzban-log status — просмотр конфигурации.
marzban-log install — установка и настройка.
marzban-log config — изменение параметров.

## ⚙️ Настройки
После установки конфигурация хранится в ```/etc/marzban_cleanup.conf``` и может редактироваться вручную или через ```marzban-log config```.

## 🔄 Обновление
```
marzban-log update
```

## 🚀 Удаление
```
sudo rm -f /usr/local/bin/marzban-log /etc/marzban_cleanup.conf
sudo crontab -l | grep -v 'marzban-log' | sudo crontab -
```

## 📄 Лицензия
MIT
```

---

Теперь у тебя удобный CLI, автоматическая установка, обновление и конфигурирование. Готов залить это в твое репо? 🚀
```
