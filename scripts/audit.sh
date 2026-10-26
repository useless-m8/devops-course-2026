#!/usr/bin/env bash
# Аудит конфигурации Ubuntu Server — практические работы № 5–7.
# Запуск на виртуальной машине: sudo bash ~/audit.sh
set -uo pipefail

PASS=0
FAIL=0

check() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        printf ' [OK]   %s\n' "$desc"
        PASS=$((PASS + 1))
    else
        printf ' [FAIL] %s (ожидалось: %s, получено: %s)\n' "$desc" "$expected" "${actual:-<пусто>}"
        FAIL=$((FAIL + 1))
    fi
}

# Функция возвращает yes, только если порт 5000 или 5432 прослушивается
# на внешнем адресе (т.е. не на loopback). IPv4 и IPv6 учитываются.
unsafe_ports() {
    ss -H -tln 2>/dev/null | awk '
        $4 ~ /:(5000|5432)$/ {
            endpoint=$4
            sub(/:(5000|5432)$/, "", endpoint)
            if (endpoint != "127.0.0.1" && endpoint != "[::1]" && endpoint != "::1") {
                bad=1
            }
        }
        END { print bad ? "yes" : "no" }
    '
}

printf 'Аудит конфигурации: %s, %s\n' "$(hostname -f)" "$(date '+%Y-%m-%d %H:%M')"

echo '[1] Служба SSH'
sshd_settings="$(sshd -T 2>/dev/null || true)"
check 'Вход от имени root запрещён' 'no' "$(awk '$1=="permitrootlogin" {print $2; exit}' <<< "$sshd_settings")"
check 'Парольная аутентификация отключена' 'no' "$(awk '$1=="passwordauthentication" {print $2; exit}' <<< "$sshd_settings")"
check 'Порт SSH — 2222' '2222' "$(awk '$1=="port" {print $2; exit}' <<< "$sshd_settings")"
check 'MaxAuthTries — 3' '3' "$(awk '$1=="maxauthtries" {print $2; exit}' <<< "$sshd_settings")"

echo '[2] Межсетевой экран'
check 'UFW активен' 'active' "$(ufw status 2>/dev/null | awk '/^Status:/ {print $2; exit}')"
check 'Входящая политика UFW — deny' 'deny' "$(ufw status verbose 2>/dev/null | awk '/^Default:/ {print $2; exit}')"

echo '[3] Учётные записи'
awk -F: '$3>=1000 && $3<65534 {printf " %s (uid=%s)\n", $1, $3}' /etc/passwd

echo '[4] Веб-сервер'
check 'Служба nginx активна' 'active' "$(systemctl is-active nginx 2>/dev/null || true)"
check 'Конфигурация nginx корректна' 'yes' "$(nginx -t >/dev/null 2>&1 && echo yes || echo no)"
check 'Сертификат действителен ещё >= 30 дней' 'yes' "$(openssl x509 -in /etc/ssl/certs/devops.crt -noout -checkend 2592000 >/dev/null 2>&1 && echo yes || echo no)"
check 'Нет файлов с world-write и права ключа 600' 'yes' "$(
    if [[ "$(stat -c '%a' /etc/ssl/private/devops.key 2>/dev/null)" == '600' ]] \
        && [[ -z "$(find /var/www/devops-site -type f -perm -o+w -print -quit 2>/dev/null)" ]]; then
        echo yes
    else
        echo no
    fi
)"

echo '[5] Контейнеризация'
check 'Служба docker активна' 'active' "$(systemctl is-active docker 2>/dev/null || true)"
check 'Контейнер PostgreSQL healthy' 'healthy' "$(docker inspect -f '{{.State.Health.Status}}' app-db-1 2>/dev/null || true)"
check 'Нет внешних прослушиваний портов 5000/5432' 'no' "$(unsafe_ports)"
check 'Права ~/app/.env — 600' '600' "$(stat -c '%a' /home/devops/app/.env 2>/dev/null || true)"

printf '\nПройдено: %d, не пройдено: %d\n' "$PASS" "$FAIL"
if (( FAIL == 0 )); then
    exit 0
else
    exit 1
fi
