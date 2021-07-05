#!/bin/bash

work_dir='bitrix-install'

command='none'
wait_time_question=10

function Package {
    local package_command=$1
    local package_name=$2

    local package_status=null

    if dpkg-query -l | grep $package_name > /dev/null 2>&1 ; then
        package_status=true
    else 
        package_status=false
    fi

    if [ $package_command = 'install' ] ; then
        if ! $package_status ; then
            echo -n "$package_name install"
            apt -y install $package_name > /dev/null 2>&1
            echo -e " - \e[32mdone\e[39m"
        elif $package_status ; then
            echo -e "$package_name - \e[32minstalled\e[39m"
        fi
    elif [ $package_command = 'delete' ] ; then
        if ! $package_status ; then
            echo -e "$package_name - \e[31mnot installed\e[39m"
        elif $package_status ; then
            echo -n "$package_name removed"
            apt -y remove --purge $package_name* > /dev/null 2>&1
            echo -e " - \e[32mdone\e[39m"
        fi
    elif [ $package_command = 'check' ] ; then
        if $package_status ; then
            echo 'true'
        else
            echo 'false'
        fi
    fi
}

while [ -n "$1" ] ; do
    case "$1" in
        -install) command='install' ;;
        -get_key) command='get_key' ;;
        -delete) command='delete' ;;
        -update) command='update' ;;
    esac

    shift
done

if [ $command = 'install' ] ; then
    apt update > /dev/null 2>&1

    update_nginx_default=false
    update_php_ini=false
    create_mysql_base=false

    if [ $(Package check nginx) = 'false' ] ; then
        update_nginx_default=true
    fi

    if [ $(Package check php-fpm) = 'false' ] ; then
        update_php_ini=true
    fi

    if [ $(Package check mysql-server) = 'false' ] ; then
        create_mysql_base=true
    fi

    Package install nginx

    if $update_nginx_default ; then
        echo -n -e " \e[96m+\e[39m update settings nginx"

        if [ -f '/var/www/html/index.nginx-debian.html' ] ; then
            rm /var/www/html/index.nginx-debian.html
        fi

        sed -i -e '
            44s|index.nginx-debian.html|index.php|
            56s|#||
            57s|#||
            60s|#||
            63s|#||
        ' /etc/nginx/sites-available/default

        systemctl restart nginx

        echo -e " - \e[32mdone\e[39m"
    fi

    Package install php-fpm
    echo -n -e "\e[33m * \e[39m"; Package install php-mbstring
    echo -n -e "\e[33m * \e[39m"; Package install php-mysql
    echo -n -e "\e[33m * \e[39m"; Package install php-gd
    echo -n -e "\e[33m * \e[39m"; Package install php-xml

    if $update_php_ini ; then
        echo -n -e " \e[96m+\e[39m update php.ini"

        sed -i -e '
            s|short_open_tag = Off|short_open_tag = On|
            s|display_errors = Off|display_errors = On|
            s|memory_limit = 128|memory_limit = 256|
            s|;max_input_vars = 1000|max_input_vars = 10000|
            s|;date.timezone =|date.timezone = Asia/Vladivostok|
            s|;opcache.revalidate_freq=2|opcache.revalidate_freq=0|
            s|;opcache.max_accelerated_files=10000|opcache.max_accelerated_files=100000|
        ' /etc/php/7.4/fpm/php.ini

        systemctl restart php7.4-fpm

        echo -e " - \e[32mdone\e[39m"
    fi

    Package install mysql-server

    if $create_mysql_base ; then
        echo -n -e " \e[96m+\e[39m update my.cnf"

        echo -e "\n[mysqld]\ndefault-time-zone = '+10:00'\ninnodb_strict_mode = 0\ninnodb_flush_log_at_trx_commit = 2\nsync_binlog = 0\ninnodb_flush_method = O_DIRECT\ntransaction-isolation = READ-COMMITTED\n\ninnodb_buffer_pool_size = 1G\ninnodb_log_file_size = 512M\n\nsort_buffer_size = 1M\nread_rnd_buffer_size = 1M\n\nmax_connections = 200\n\nslow_query_log = 1\nslow_query_log_file = /var/log/mysql/slow_queries.log\nlong_query_time = 0.5" >> /etc/mysql/my.cnf

        systemctl restart mysql

        echo -e " - \e[32mdone\e[39m"

        echo -e " \e[96m+\e[39m create mysql user and base"

        read -e -t $wait_time_question -p $' \e[96m|>\e[39m user-login: ' -i "bitrix" mysql_user

        if [ -z $mysql_user ] ; then
            echo ''
            mysql_user='bitrix'
        fi

        read -e -t $wait_time_question -p $' \e[96m|>\e[39m user-pass: ' -i "qwe123" mysql_pass

        if [ -z $mysql_pass ] ; then
            echo ''
            mysql_pass='qwe123'
        fi

        read -e -t $wait_time_question -p $' \e[96m|>\e[39m bitrix-base: ' -i "sitemanager" mysql_base

        if [ -z $mysql_base ] ; then
            echo ''
            mysql_base='sitemanager'
        fi

        mysql --execute="CREATE USER '$mysql_user'@'localhost' IDENTIFIED BY '$mysql_pass'; GRANT ALL PRIVILEGES ON * . * TO '$mysql_user'@'localhost'; FLUSH PRIVILEGES; CREATE DATABASE $mysql_base;"

        echo -e "\e[4A\e[29C - \e[32mdone\e[39m\e[3B"
    fi

    if [ -d "/var/www/html" ] ; then
        if [ ! -d $work_dir ] ; then
            mkdir $work_dir
        fi

        if [ ! -f $work_dir/bitrix.tar.gz ] ; then
            echo -n 'download bitrix.tar.gz'
            wget -O $work_dir/bitrix.tar.gz https://www.1c-bitrix.ru/download/files/business_encode.tar.gz > /dev/null 2>&1
            echo -e " - \e[32mdone\e[39m"
        fi

        echo -n 'unpack bitrix.tar.gz in /var/www/html'
        tar -C /var/www/html/ -xzf $work_dir/bitrix.tar.gz
        echo -e " - \e[32mdone\e[39m"

        rm -r $work_dir

        chown -R www-data:www-data /var/www/html
    fi
elif [ $command = 'delete' ] ; then
    read -e -t $wait_time_question -p "Delete nginx php mysql (yes/no)? " -i "no" package_question

    if [ -z $package_question ] ; then
        echo ''
        package_question='no'
    fi

    if [ $package_question = 'yes' ] ; then
        apt update > /dev/null 2>&1

        Package delete nginx
        Package delete php
        Package delete mysql
    fi

    if [ -d "/var/lib/mysql" ] ; then
        rm -rf /var/lib/mysql*
    fi

    if [ -d "/var/www/html" ] ; then
        echo -n "delete bitrix file"
        rm -rf /var/www/html/
        echo -e " - \e[32mdone\e[39m"
    fi

    if [ -d $work_dir ] ; then
        rm -r $work_dir
    fi
elif [ $command = 'get_key' ] ; then
    read -e -t $wait_time_question -p $'bitrix-base: ' -i "sitemanager" mysql_base

    if [ -z $mysql_base ] ; then
        echo ''
        mysql_base='sitemanager'
    fi

    ip="$(ip a | grep -Po "(?<=inet )\d*\.\d*\.\d*\.\d*(?=\/24)")"
    php_key="$(grep -Po "(?<=\")(?!TEMPORARY_CACHE)\w*\d*(?=\")" /var/www/html/bitrix/modules/main/admin/define.php)"
    mysql_key="$(mysql -N -B -e "use $mysql_base; SELECT VALUE FROM b_option WHERE NAME = 'admin_passwordh';")"
    bitrix_key="$(grep -Po "(?<=\").*(?=\")" /var/www/html/bitrix/license_key.php)"

    echo -e "\e[32mserver ip\e[39m \e[93m$ip\e[39m\n\e[34mphp key\e[39m \e[90m(bitrix/modules/main/admin/define.php)\e[39m \e[92m$php_key\e[39m\n\e[34mmysql key\e[39m \e[90m(b_option.admin_passwordh.value)\e[39m \e[92m$mysql_key\e[39m\n\e[34mbitrix key\e[39m \e[90m(bitrix/license_key.php)\e[39m \e[92m$bitrix_key\e[39m"
elif [ $command = 'update' ] ; then
    echo 'update'
else
    echo 'wrong command, choose one of the existing -install -get_key -delete'
fi