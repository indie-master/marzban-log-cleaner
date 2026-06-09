# Marzban Log Cleaner

`marzban-log-cleaner` — универсальный CLI-инструмент для управляемой очистки логов. Проект больше не привязан к фиксированным файлам Marzban/Marzban Node: любые логи, сроки хранения и действия задаются в YAML-конфиге.

## Возможности

- Очистка любого количества лог-файлов по кастомным путям.
- Отдельный `max_age` для каждого файла: минуты, часы или дни (`30m`, `12h`, `7d`, `30d`).
- Два действия очистки:
  - `truncate` — очистить содержимое, оставив файл на месте;
  - `delete` — удалить файл полностью.
- `enabled: false` для временного отключения отдельного правила.
- Безопасная обработка отсутствующих файлов и ошибок прав доступа.
- `dry-run` режим для проверки без изменений.
- Установка systemd timer для автоматической очистки по текущему конфигу.
- Совместимость с командами `marzban-log clean`, `marzban-log status`, `marzban-log update` и legacy-wrapper `marzban_log_cleanup.sh`.

## Установка

```bash
git clone https://github.com/indie-master/marzban-log-cleaner.git
cd marzban-log-cleaner
sudo ./install.sh
```

Альтернативно можно скачать только CLI:

```bash
sudo curl -fsSL https://raw.githubusercontent.com/indie-master/marzban-log-cleaner/main/marzban-log -o /usr/local/bin/marzban-log
sudo chmod +x /usr/local/bin/marzban-log
sudo marzban-log install
```

Установка делает следующее:

1. устанавливает CLI в `/usr/local/bin/marzban-log`;
2. создаёт `/etc/marzban-log-cleaner/config.yml`, если его ещё нет;
3. не перезаписывает существующий конфиг;
4. создаёт backup существующего конфига/юнитов перед изменениями;
5. устанавливает и включает `marzban-log-cleaner.timer`.

## Конфиг

Путь по умолчанию:

```text
/etc/marzban-log-cleaner/config.yml
```

Пример:

```yaml
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

  - name: custom-nginx-log
    path: /var/log/nginx/custom.log
    max_age: 30d
    action: delete
    enabled: false
```

### Поля правила

| Поле | Описание |
| --- | --- |
| `name` | Человекочитаемое имя правила в логах CLI. |
| `path` | Абсолютный или относительный путь к файлу лога. |
| `max_age` | Минимальный возраст файла по `mtime`, после которого можно очищать: `30m`, `12h`, `7d`, `30d`. |
| `action` | `truncate` или `delete`. |
| `enabled` | `true` — правило активно, `false` — пропускается. |

> Важно: `max_age` проверяется по времени последней модификации файла (`mtime`). Если файл моложе указанного срока, команда `clean` пропустит его.

## CLI-команды

### Справка

```bash
marzban-log
```

Показывает список доступных команд.

### Статус

```bash
marzban-log status
```

Показывает путь к конфигу, список правил, действие, срок хранения, существование файла, возраст и размер файла.

### Очистка

```bash
sudo marzban-log clean
```

Запускает очистку вручную по текущему конфигу.

### Dry-run

```bash
marzban-log clean --dry-run
```

Показывает, какие файлы были бы очищены или удалены, но ничего не меняет.

### Информация о конфиге

```bash
marzban-log config
```

Показывает путь к конфигу и короткий пример настройки.

### Добавление правила

```bash
sudo marzban-log add
```

Интерактивно добавляет новый путь в конфиг. Перед записью создаётся backup текущего конфига.

### Редактирование конфига

```bash
sudo marzban-log edit
```

Открывает конфиг в `$EDITOR`, либо в `nano`, если `$EDITOR` не задан. Перед редактированием создаётся backup.

### Проверка конфига

```bash
marzban-log validate
```

Проверяет YAML-конфиг и правила, не выполняя очистку.

### Обновление

```bash
sudo marzban-log update
```

Скачивает актуальный CLI, сохраняет существующий конфиг и обновляет systemd unit/timer.

## Примеры

### Добавить кастомный nginx-лог вручную

```yaml
logs:
  - name: nginx-api-access
    path: /var/log/nginx/api.access.log
    max_age: 30d
    action: truncate
    enabled: true
```

### Разное время хранения для разных файлов

```yaml
logs:
  - name: app-debug
    path: /var/log/my-app/debug.log
    max_age: 12h
    action: truncate
    enabled: true

  - name: app-audit-archive
    path: /var/log/my-app/audit.old.log
    max_age: 30d
    action: delete
    enabled: true
```

### Временно отключить правило

```yaml
logs:
  - name: temporary-log
    path: /tmp/example.log
    max_age: 30m
    action: delete
    enabled: false
```

## Предупреждение про `truncate` и `delete`

- Используйте `truncate` для логов, которые могут быть открыты работающими сервисами. Это очищает содержимое, но сохраняет файл и inode, поэтому сервис обычно продолжает писать в тот же файл без перезапуска.
- Используйте `delete` только если вы уверены, что сервис корректно пересоздаёт лог или не держит файл открытым. Удаление файла, открытого процессом, может не освободить место до перезапуска процесса.

## Автоматическая очистка

Установщик создаёт systemd timer:

```bash
systemctl status marzban-log-cleaner.timer
systemctl list-timers marzban-log-cleaner.timer
```

По умолчанию timer запускает:

```bash
/usr/local/bin/marzban-log clean
```

Поскольку правила читаются из `/etc/marzban-log-cleaner/config.yml` при каждом запуске, изменение конфига сразу влияет на следующую автоматическую очистку.

## Troubleshooting

### Конфиг отсутствует

Запустите:

```bash
sudo marzban-log config
```

CLI создаст дефолтный конфиг, если есть права на запись в `/etc/marzban-log-cleaner`.

### Битый YAML или ошибка в полях

```bash
marzban-log validate
```

Команда покажет строку/поле с ошибкой. Поддерживается простой YAML-формат со списком `logs`; сложные YAML-конструкции вроде anchors не нужны.

### Файл лога отсутствует

Это не ошибка. `clean` выведет `SKIP ... файл отсутствует` и продолжит обработку остальных правил.

### Нет прав на очистку

Запустите очистку через `sudo` или настройте права на конкретный лог:

```bash
sudo marzban-log clean
```

### Проверить, что будет сделано

```bash
marzban-log clean --dry-run
```

### Проверить systemd timer

```bash
systemctl status marzban-log-cleaner.timer
journalctl -u marzban-log-cleaner.service --no-pager -n 100
```

## Удаление

```bash
sudo systemctl disable --now marzban-log-cleaner.timer
sudo rm -f /etc/systemd/system/marzban-log-cleaner.service /etc/systemd/system/marzban-log-cleaner.timer
sudo systemctl daemon-reload
sudo rm -f /usr/local/bin/marzban-log
# опционально, если конфиг больше не нужен:
# sudo rm -rf /etc/marzban-log-cleaner
```

## Лицензия

MIT
