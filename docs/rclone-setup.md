# Настройка rclone для gnome-gdrive-mount

Скрипт `gdrive-mount` ждёт, что в конфигурации `rclone` есть remote с именем **ровно** `gdrive:` (имя зашито в `src/gdrive-mount:5`). Никаких других опций скрипт не передаёт — кэш и поведение берутся из remote-конфига и из флага `--vfs-cache-mode writes` в самом скрипте.

## 1. Установка rclone

```bash
# Debian / Ubuntu
sudo apt install rclone

# Fedora
sudo dnf install rclone

# Arch
sudo pacman -S rclone
```

Актуальную версию также можно поставить единым бинарником с https://rclone.org/install/.

## 2. Создание remote

Запустите интерактивный конфигуратор:

```bash
rclone config
```

Шаги:

1. `n` — создать новый remote.
2. `name>` — ввести **`gdrive`** (без двоеточия; `rclone` хранит имя без `:` и подставляет его при обращении).
3. `Storage>` — выбрать **`drive`** (пункт «Google Drive» в списке) — обычно это `XX` / `XX / Google Drive`, точный номер зависит от версии, ориентируйтесь по тексту.
4. `client_id>` и `client_secret>` — оставить пустыми, нажать Enter. `rclone` использует свои общие OAuth-ключи, для личного использования этого достаточно.
5. `scope>` — для монтирования достаточно scope по умолчанию (`1` — Full access). Если нужна только «только чтение», выберите подходящий, но для нормальной работы скрипта нужен полный доступ.
6. `service_account_file>` — оставить пустым, Enter.
7. `Edit advanced config?` — `n` (не нужно).
8. `Use web browser?` — `y`, если есть GUI-браузер; в headless-среде выбрать `n` и следовать подсказке с `rclone authorize` на другой машине.
9. В браузере залогиниться в нужный Google-аккаунт и разрешить доступ.
10. `Keep this remote?` — `y`.
11. `q` — выйти.

Проверить, что remote появился:

```bash
rclone listremotes
# должно быть:
# gdrive:

rclone lsd gdrive:
# должен вывести список каталогов в корне Диска
```

## 3. Проверка перед первым монтированием

```bash
rclone lsd gdrive:        # список каталогов
rclone about gdrive:      # информация о квоте
```

Если обе команды отрабатывают без ошибок — скрипт `gdrive-mount` будет работать.

## 4. Частые проблемы

- **`Failed to create file system for "gdrive:": didn't find section in config file`** — remote не создан или имя введено не `gdrive`. Проверьте `rclone listremotes`.
- **Ошибка авторизации / токен устарел** — пересоздайте токен: `rclone config reconnect gdrive:`.
- **`Permission denied` при монтировании** — обычно значит, что FUSE недоступен текущему пользователю. На большинстве дистрибутивов добавляет себя в группу `fuse`: `sudo usermod -aG fuse $USER` (нужен перелогин).
- **Монтирование «висит» или отваливается** — это уже зона скрипта, см. README.
