

\# Конфигурация виртуальной машины devops-vm



\## 1. Параметры машины



\- ОС: Ubuntu Server 24.04 LTS

\- Гипервизор: VirtualBox 7.x

\- Оперативная память: 2048 МБ

\- Процессор: 2 ядра

\- Диск: 25 ГБ, динамический



\## 2. Сетевые интерфейсы



Адаптер 1:

\- Тип: NAT

\- IP: 10.0.2.15

\- Назначение: доступ в Интернет



Адаптер 2:

\- Тип: Host-only

\- IP: 192.168.56.102

\- Назначение: связь с Windows



\## 3. Проброс портов



\- Протокол: TCP

\- IP хоста: 127.0.0.1

\- Порт хоста: 2222

\- Порт гостевой системы: 2222



\## 4. Учётные записи



student:

\- первоначальная учётная запись

\- административные права через sudo



devops:

\- отдельный пользователь для администрирования

\- группа sudo

\- аутентификация по SSH-ключу ED25519



\## 5. Служба SSH



Конфигурационный файл:

/etc/ssh/sshd\_config.d/99-hardening.conf



Параметры:

\- Port 2222

\- PermitRootLogin no

\- PasswordAuthentication no

\- PubkeyAuthentication yes

\- PermitEmptyPasswords no

\- MaxAuthTries 3

\- LoginGraceTime 30

\- AllowUsers devops

\- X11Forwarding no

\- ClientAliveInterval 300

\- ClientAliveCountMax 2



Служба ssh.socket отключена.

Используется ssh.service.



\## 6. Правила межсетевого экрана



UFW активен.



Политики:

\- deny incoming

\- allow outgoing



Разрешённые порты:

\- 2222/tcp — LIMIT

\- 80/tcp — ALLOW

\- 443/tcp — ALLOW



Логирование: medium.



\## 7. Снимки состояния



\- 01-clean-install — чистая установка Ubuntu

\- 02-keys-configured — настройка SSH-ключей

\- 03-ssh-hardened — усиление защиты SSH



\## 8. Проверка и восстановление



Проверка SSH:

sudo sshd -t

sudo sshd -T



Проверка UFW:

sudo ufw status verbose



Проверка аудита:

bash scripts/audit.sh



После восстановления снимка 01-clean-install

необходимо повторно создать пользователя devops,

установить его публичный SSH-ключ, восстановить

настройки SSH, проброс портов и правила UFW.



## 8. Веб-сервер

На Ubuntu Server используется веб-сервер **Nginx**, установленный из пакета `nginx`.

Конфигурация ресурса `devops.local` находится в `/etc/nginx/sites-available/devops-site`. В каталоге `/etc/nginx/sites-enabled/` создана символическая ссылка на неё. Стандартный сайт Nginx отключён.

Статические файлы находятся в `/var/www/devops-site/`. Владелец каталога и файлов — `devops:devops`. Права каталогов — `755`, файлов — `644`. Пользователь `www-data` может читать опубликованные файлы, но не изменять их.

Сервер принимает HTTP-запросы на порту 80 и перенаправляет их на HTTPS (порт 443, код 301).

Используется самоподписанный TLS-сертификат со сроком действия 365 дней:

- Сертификат: `/etc/ssl/certs/devops.crt`, права `644`.
- Приватный ключ: `/etc/ssl/private/devops.key`, права `600`.

Команда формирования сертификата:

```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/devops.key \
  -out /etc/ssl/certs/devops.crt \
  -subj "/CN=devops.local" \
  -addext "subjectAltName=DNS:devops.local"
```

Проверка конфигурации:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

Содержимое ресурса доставляется из каталога `site/` Git-репозитория через `rsync`. Для автоматизированной доставки используется `scripts/deploy.sh`.
