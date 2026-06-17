#!/bin/bash
# Установщик gnome-gdrive-mount.
# Проверяет зависимости (на debian-based предлагает apt-get install),
# копирует скрипт и .desktop-файл в пользовательские каталоги.
# Запускать из корня репозитория: ./install.sh

set -u

# Каталог, в котором лежит сам install.sh — от него ищем src/.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"

BIN_TARGET="$HOME/.local/bin/gdrive-mount"
DESKTOP_TARGET_DIR="$HOME/.local/share/applications"
DESKTOP_TARGET="$DESKTOP_TARGET_DIR/rclone-gdrive.desktop"

# ---------- Вывод справки ----------

show_help() {
    cat <<'EOF'
Использование: ./install.sh

Устанавливает gnome-gdrive-mount в домашний каталог:
  - src/gdrive-mount              -> ~/.local/bin/gdrive-mount
  - src/rclone-gdrive.desktop     -> ~/.local/share/applications/

Проверяет наличие rclone, fusermount, mountpoint. На дистрибутивах
семейства Debian при отсутствии пакета предлагает поставить его
через sudo apt-get install.

Скрипт работает идемпотентно: повторный запуск безопасен и обновляет
уже установленные файлы.
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    show_help
    exit 0
fi

# ---------- Проверка, что мы в репозитории ----------

if [ ! -d "$SRC_DIR" ] || [ ! -f "$SRC_DIR/gdrive-mount" ] || [ ! -f "$SRC_DIR/rclone-gdrive.desktop" ]; then
    echo "ОШИБКА: не найдены файлы в $SRC_DIR."
    echo "Запускайте install.sh из корня репозитория."
    exit 1
fi

# ---------- Определение debian-based ----------

is_debian_like() {
    # /etc/os-release есть практически везде с systemd, и в debian/ubuntu/mint.
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        case "${ID:-}${ID_LIKE:-}" in
            *debian*|*ubuntu*) return 0 ;;
        esac
    fi
    return 1
}

DEBIAN_LIKE=0
if is_debian_like; then
    DEBIAN_LIKE=1
fi

# ---------- Проверка зависимостей ----------

need_root_apt() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "sudo "
    fi
}

# Сопоставление: имя_утилиты -> имя_пакета в apt.
# rclone иногда ставится из отдельного репозитория, но в новых Debian/Ubuntu
# (Debian 12+, Ubuntu 22.04+) уже есть в main. Если пакета в репозитории нет,
# apt-get всё равно предложит свой путь.
declare -A APT_PKG=(
    [rclone]=rclone
    [fusermount]=fuse3
    [mountpoint]=util-linux
)

# Возвращает 0, если пакет можно поставить через apt (т.е. на debian-like).
# Печатает имя пакета, если всё ок.
apt_info_for() {
    local util="$1"
    if [ "$DEBIAN_LIKE" -eq 0 ]; then
        return 1
    fi
    local pkg="${APT_PKG[$util]:-}"
    if [ -z "$pkg" ]; then
        return 1
    fi
    echo "$pkg"
    return 0
}

# Установить один пакет (после согласия пользователя).
install_apt_pkg() {
    local pkg="$1"
    echo "Ставлю пакет '$pkg' через apt-get..."
    # shellcheck disable=SC2086
    if $(need_root_apt) apt-get install -y "$pkg"; then
        echo "Пакет '$pkg' установлен."
        return 0
    else
        echo "ОШИБКА: не удалось установить '$pkg'."
        return 1
    fi
}

ask_yn() {
    local prompt="$1"
    local ans
    while :; do
        # -r важно: без него Enter = пустая строка = дефолт.
        read -r -p "$prompt [y/N]: " ans
        case "$ans" in
            y|Y|д|Д|yes|Yes|YES) return 0 ;;
            n|N|н|Н|no|No|NO|"") return 1 ;;
            *) echo "Ответьте y или n." ;;
        esac
    done
}

MISSING=()
for util in rclone fusermount mountpoint; do
    if ! command -v "$util" >/dev/null 2>&1; then
        MISSING+=("$util")
    fi
done

if [ "${#MISSING[@]}" -gt 0 ]; then
    echo "Найдены отсутствующие зависимости: ${MISSING[*]}"
    if [ "$DEBIAN_LIKE" -eq 1 ]; then
        echo "Обнаружен дистрибутив семейства Debian — могу поставить через apt-get."
        if ask_yn "Поставить недостающие пакеты?"; then
            FAILED=()
            for util in "${MISSING[@]}"; do
                pkg=$(apt_info_for "$util") || { FAILED+=("$util"); continue; }
                install_apt_pkg "$pkg" || FAILED+=("$util")
            done
            if [ "${#FAILED[@]}" -gt 0 ]; then
                echo ""
                echo "Не удалось подготовить всё окружение. Не установлены: ${FAILED[*]}"
                echo "Поставьте их вручную и запустите install.sh снова."
                exit 1
            fi
        else
            echo "Установка пакетов пропущена. Продолжаю копирование файлов,"
            echo "но без зависимостей скрипт gdrive-mount работать не будет."
        fi
    else
        echo "Этот дистрибутив не относится к семейству Debian — apt-get я не вызываю."
        echo "Поставьте утилиты ${MISSING[*]} вручную (через пакетный менеджер вашего дистрибутива)"
        echo "и запустите install.sh снова."
        echo "Продолжаю копирование файлов — это не зависит от пакетов."
    fi
else
    echo "Все зависимости на месте: rclone, fusermount, mountpoint."
fi

# ---------- Копирование файлов ----------

mkdir -p "$HOME/.local/bin" "$DESKTOP_TARGET_DIR"

echo "Копирую $SRC_DIR/gdrive-mount  ->  $BIN_TARGET"
install -m 755 "$SRC_DIR/gdrive-mount" "$BIN_TARGET"

echo "Копирую $SRC_DIR/rclone-gdrive.desktop  ->  $DESKTOP_TARGET"
install -m 644 "$SRC_DIR/rclone-gdrive.desktop" "$DESKTOP_TARGET"

# ---------- Проверка PATH ----------

# Проверяем, что ~/.local/bin реально в $PATH.
case ":${PATH}:" in
    *":$HOME/.local/bin:"*) ;;
    *)
        echo ""
        echo "ВНИМАНИЕ: '$HOME/.local/bin' отсутствует в PATH."
        echo "Чтобы запускать 'gdrive-mount' из терминала без полного пути, добавьте в ~/.profile:"
        echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo "и перелогиньтесь, либо откройте новый шелл."
        ;;
esac

# ---------- Подсказка про rclone remote ----------

if command -v rclone >/dev/null 2>&1; then
    if ! rclone listremotes 2>/dev/null | grep -qx "gdrive:"; then
        echo ""
        echo "ВНИМАНИЕ: rclone remote 'gdrive:' не найден."
        echo "Настройте его перед первым монтированием: см. docs/rclone-setup.md."
    fi
fi

echo ""
echo "Установка завершена."
echo "Запустите 'gdrive-mount' (или найдите 'Google Drive' в меню приложений)."
