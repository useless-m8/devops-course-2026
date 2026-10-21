
#!/usr/bin/env bash
# Доставка статического ресурса на devops-vm
# Использование: scripts/deploy.sh [--dry-run]
set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
LOCAL_DIR="${REPO_ROOT}/site/"
DRY_RUN=false

# 1. Обработка аргументов
if [[ $# -gt 1 ]]; then
    echo "Ошибка: допустим только аргумент --dry-run" >&2
    exit 1
fi

if [[ $# -eq 1 ]]; then
    if [[ "$1" == "--dry-run" ]]; then
        DRY_RUN=true
    else
        echo "Ошибка: неизвестный аргумент $1" >&2
        exit 1
    fi
fi

# 2. Проверка главной страницы
if [[ ! -f "${LOCAL_DIR}index.html" ]]; then
    echo "Ошибка: файл site/index.html отсутствует" >&2
    exit 1
fi

# 3. Проверка Git
if [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
    echo "Ошибка: в репозитории есть незакоммиченные изменения" >&2
    exit 1
fi

COMMIT="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"

# 4. Синхронизация через одно SSH-соединение
RSYNC_ARGS=(-avz --delete --chmod=D755,F644)

if [[ "$DRY_RUN" == true ]]; then
    RSYNC_ARGS+=(--dry-run)
    echo "Пробная доставка коммита ${COMMIT}"
else
    echo "Доставка коммита ${COMMIT}"
fi

rsync "${RSYNC_ARGS[@]}" \
    -e "ssh -o BatchMode=yes -o ConnectTimeout=5" \
    "$LOCAL_DIR" "${REMOTE}:${REMOTE_DIR}/"

# 5. В dry-run сервер не проверяем
if [[ "$DRY_RUN" == true ]]; then
    echo "Пробная доставка завершена"
    exit 0
fi

# 6. Проверка HTTPS
if [[ ! -f "$CA_CERT" ]]; then
    echo "Ошибка: сертификат $CA_CERT не найден" >&2
    exit 1
fi

if ! curl -fsS --cacert "$CA_CERT" \
    -o /dev/null "$SITE_URL"; then
    echo "Ошибка: сайт недоступен по HTTPS" >&2
    exit 1
fi

echo "Деплой успешно завершён. Коммит: ${COMMIT}"
exit 0
