# bitrix-license-extend
Этот скрипт автоматически разворачивает 1c-битрикс на вашем сервере (Ubuntu 20.04).

**Скрипт запускается под root!**

скрипт запускается командой:
`./bitrix-install.sh`

Производится скачивание и установка последней версии 1c-bitrix с оффсайта, так же устанавливаются все неообходимые компоненты:
```text
nginx
php-fpm
    php-mbstring
    php-mysql
    php-gd
    php-xml
mysql-server
```
Так же производится настройка компонентов:

**nginx (/etc/nginx/sites-available/default):**
```text
    index index.html index.htm index.php;

    location ~ \.php$ {
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
    }
```

**php (/etc/php/7.4/fpm/php.ini):**
```text
    short_open_tag = On
    display_errors = On
    memory_limit = 256
    max_input_vars = 10000
    date.timezone = Asia/Vladivostok
    opcache.revalidate_freq=0
    opcache.max_accelerated_files=100000
```

**mysql (/etc/mysql/my.cnf):**
```text
    [mysqld]
    default-time-zone = '+10:00'
    innodb_strict_mode = 0
    innodb_flush_log_at_trx_commit = 2
    sync_binlog = 0
    innodb_flush_method = O_DIRECT
    transaction-isolation = READ-COMMITTED

    innodb_buffer_pool_size = 1G
    innodb_log_file_size = 512M

    sort_buffer_size = 1M
    read_rnd_buffer_size = 1M

    max_connections = 200

    slow_query_log = 1
    slow_query_log_file = /var/log/mysql/slow_queries.log
    long_query_time = 0.5
```

Так же создается пользователь и база данных в mysql (default):
**user:** `bitrix`
**pass:** `qwe123`
**base:** `sitemanager`

**Сам битрикс надо устанавливать и настраивать самостоятельно!**

Удалить все пакеты и битрикс, можно командой:
`./bitrix-install.sh -delete`

**Скрипт запускается под root!**