#!/bin/bash
#===============================================================================
#
#          FILE: init.sh
#
#         USAGE: ./init.sh host_name
#
#   DESCRIPTION: 初始化
#
#        AUTHOR: xx
#
#       CREATED: 2013/10/25 09:54
#===============================================================================

function f_print_help
{
    F_PRINT_HELP " USAGE: $0 -h host_name -t time_zone -n ntp_server
    "
}

function f_cd_tar
{
    local pkg=${1}
    
    cd ${pkg_path}
    local pkg_file=$(find -maxdepth 1 -type f -name "${pkg}*")
    
    find -maxdepth 1 -type d -name "${pkg}*" | xargs -l rm -rf
    
    tar -xf ${pkg_file} -C ${tmp_path}/init/
    F_LOG_EXIT " 解压${pkg} ${pkg_file} " ${log_file}
    
    cd ${tmp_path}/init && \
    local pkg_path=$(find -maxdepth 1 -type d -name "${pkg}*") && \
    cd ${pkg_path}
    F_LOG_EXIT " CD ${pkg} ${pkg_path} " ${log_file}
}

function f_add_bin_path
{
    local bin=${1}
    
    if [ ! -f /etc/profile.d/devel.sh ]; then
        touch /etc/profile.d/devel.sh
    fi
    
    if ! grep -q "${bin}" /etc/profile.d/devel.sh; then
        echo 'export PATH=$PATH:'${bin}'' >> /etc/profile.d/devel.sh
    fi
    
    if ! echo "${PATH}" | grep -q grep -q "${bin}"; then
        export PATH=${PATH}:${bin}
    fi

    F_LOG_EXIT " ADD BIN PATH ${bin} " ${log_file}
}

function install_base
{
    F_CHECK_STEP "INSTALL BASE" ${step_file} && { F_LOG_SUCCESS " BASE 已安装 " ${log_file}; return 0;}
    
    hostname ${host_name}
    F_LOG_EXIT " INIT HOSTNAME ${host_name} " ${log_file}
    
	apt-get update && \
    apt-get install -y libreadline-dev libncurses5-dev libpcre3-dev libssl-dev perl make build-essential autoconf git wget lrzsz
    F_LOG_EXIT " 安装基础库 " ${log_file}

    F_SAVE_STEP "INSTALL BASE" ${step_file}
}

function checkout_reps
{
    F_CHECK_STEP "CHECKOUT REPS" ${step_file} && { F_LOG_SUCCESS " REPS 已部署 " ${log_file}; return 0;}
    
    mkdir -p ${www_path}/server && \
    git clone https://github.com/tigit/papa-server.git ${www_path}/server && \
	mkdir -p ${www_path}/console && \
    git clone https://github.com/tigit/papa-console.git ${www_path}/console
    F_LOG_EXIT " 部署服务器代码 " ${log_file}
    
    F_SAVE_STEP "CHECKOUT PKGS" ${step_file}
}

function download_pkgs
{
    F_CHECK_STEP "DOWNLOAD PKGS" ${step_file} && { F_LOG_SUCCESS " PKGS 已下载 " ${log_file}; return 0;}
    
    mkdir -p ./pkg && \
    wget http://pecl.php.net/get/memcached-2.2.0.tgz -P ./pkg && \
    wget http://cn2.php.net/distributions/php-5.6.16.tar.bz2 -P ./pkg && \
    wget http://download.redis.io/releases/redis-3.0.5.tar.gz -P ./pkg && \
    wget http://keplerproject.github.io/luarocks/releases/luarocks-2.2.2.tar.gz -P ./pkg && \
    wget https://openresty.org/download/ngx_openresty-1.9.3.2.tar.gz -P ./pkg && \
    F_LOG_EXIT " 下载软件包 " ${log_file}
    
    F_SAVE_STEP "DOWNLOAD PKGS" ${step_file}
}

function install_php
{
    F_CHECK_STEP "INSTALL PHP" ${step_file} && { F_LOG_SUCCESS " PHP 已安装 " ${log_file}; return 0;}

    apt-get install -y libmcrypt-dev libjconv-dev libxml2-dev libbz2-dev libcurl4-openssl-dev libjpeg-dev libpng12-dev libfreetype6-dev
    F_LOG_EXIT " PHP PREPARE 安装基础库 " ${log_file}
    
    cd /usr/lib && \
    ln -s -f libjconv.a libiconv.a && \
    ln -s -f libjconv.so libiconv.so
    F_LOG_EXIT " PHP PREPARE LIBICONV " ${log_file}

    f_cd_tar php-5.6
    local php_src=$(pwd)
    local php_dst=${opt_path}/php
    local php_var=${var_path}/php

    ./configure --prefix=${php_dst} \
        --with-config-file-path=${php_dst}/etc \
        --with-libdir=lib/x86_64-linux-gnu \
        --with-mysql=mysqlnd \
        --with-mysqli=mysqlnd \
        --with-pdo-mysql=mysqlnd \
        --with-iconv-dir \
        --with-mcrypt \
        --with-freetype-dir \
        --with-jpeg-dir \
        --with-png-dir \
        --with-curl \
        --with-gd \
        --with-openssl \
        --with-bz2 \
        --with-zlib \
        --with-xmlrpc \
        --disable-rpath \
        --enable-bcmath \
        --enable-fpm \
        --enable-gd-native-ttf \
        --enable-inline-optimization \
        --enable-mbregex \
        --enable-mbstring \
        --enable-opcache \
        --enable-pcntl \
        --enable-shmop \
        --enable-sockets \
        --enable-sysvsem \
        --enable-xml \
        --enable-zip
    F_LOG_EXIT " PHP BUILD CONFIGURE " ${log_file}

    make ZEND_EXTRA_LIBS='-liconv' -j ${MAKE_J}
    F_LOG_EXIT " PHP BUILD MAKE " ${log_file}

    make install
    F_LOG_EXIT " PHP BUILD MAKE INSTALL " ${log_file}

    f_add_bin_path "${php_dst}/bin"

    id www || useradd -M -s /sbin/nologin www && groups www
    F_LOG_EXIT " PHP CONFIG 添加用户 " ${log_file}

    [ ! -f ${php_dst}/etc/php.ini ] || \cp -f ${php_dst}/etc/php.ini ${php_dst}/etc/php.ini.$(F_DATE)
    [ ! -f ${php_dst}/etc/php-fpm.conf ] || \cp -f ${php_dst}/etc/php-fpm.conf ${php_dst}/etc/php-fpm.conf.$(F_DATE)
    [ ! -f /etc/init.d/php-fpm ] || \cp -f /etc/init.d/php-fpm /etc/init.d/php-fpm.$(F_DATE)

    \cp -f ${cfg_path}/php/php.ini ${php_dst}/etc/php.ini && \
        \cp -f ${cfg_path}/php/php-fpm.conf ${php_dst}/etc/php-fpm.conf && \
        \cp -f ${cfg_path}/php/php-fpm.init /etc/init.d/php-fpm && \
        sed -i -e 's#@vardir@#'${php_var}'#' -e 's#@timezone@#'${time_zone}'#' ${php_dst}/etc/php.ini && \
        sed -i -e 's#@phpdir@#'${php_dst}'#' -e 's#@vardir@#'${php_var}'#' /etc/init.d/php-fpm && \
        chmod +x /etc/init.d/php-fpm
    F_LOG_EXIT " PHP CONFIG 修改配置 " ${log_file}

    ## 安装 pdo-mysql
    cd ${php_src}/ext/pdo_mysql && \
        ${php_dst}/bin/phpize && \
        ./configure --with-php-config=${php_dst}/bin/php-config && make -j ${MAKE_J} && make install
    F_LOG_EXIT " PHP EXTENSION PDO-MYSQL BUILD " ${log_file}

    ## 安装 memcached
    apt-get install -y memcached libmemcache-dev libmemcached-dev && \
    service memcached restart && update-rc.d memcached defaults
    F_LOG_EXIT " PHP EXTENSION memcached INSTALL " ${log_file}

    ## 安装 php-memcached
    f_cd_tar memcached
    ${php_dst}/bin/phpize && \
        ./configure --with-php-config=${php_dst}/bin/php-config --disable-memcached-sasl && make -j ${MAKE_J} && make install
    F_LOG_EXIT " PHP EXTENSION php-memcached BUILD " ${log_file}
    
    ## 安装 php-redis
    f_cd_tar phpredis
    ${php_dst}/bin/phpize && \
        ./configure --with-php-config=${php_dst}/bin/php-config && make -j ${MAKE_J} && make install
    F_LOG_EXIT " PHP EXTENSION php-phpredis BUILD " ${log_file}
    
    ## 创建目录
    mkdir -p ${php_var}/log && mkdir -p ${php_var}/run && chown www:www -R ${php_var}
    F_LOG_EXIT " PHP CONFIG 创建目录 " ${log_file}

    ## 启动 php-fpm
    chmod +x /etc/init.d/php-fpm && service php-fpm restart && update-rc.d php-fpm defaults
    F_LOG_EXIT " PHP FPM START " ${log_file}

    F_SAVE_STEP "INSTALL PHP" ${step_file}
}

function install_openresty
{
    F_CHECK_STEP "INSTALL RESTY" ${step_file} && { F_LOG_SUCCESS " RESTY 已安装 " ${log_file}; return 0;}
    
    f_cd_tar ngx_openresty-1.9
    local resty_src=$(pwd)
    local resty_dst=${opt_path}
    local resty_var=${var_path}/nginx
    
    ./configure --prefix=${resty_dst} --with-pcre-jit && make -j ${MAKE_J} && make install
    F_LOG_EXIT " RESTY INSTALL " ${log_file}
    
    f_add_bin_path "${resty_dst}/bin"
    f_add_bin_path "${resty_dst}/luajit/bin"
    f_add_bin_path "${resty_dst}/nginx/sbin"
    
    cd ${resty_dst}/luajit/bin && \
    ln -s -f luajit-2.1.0-beta1 luajit && \
    ln -s -f luajit-2.1.0-beta1 lua
    F_LOG_EXIT " RESTY LUA LINK " ${log_file}
    
    grep -q "www" /etc/passwd || useradd -M -s /sbin/nologin www && groups www
    F_LOG_EXIT " RESTY CONFIG 添加用户 " ${log_file}

    [ ! -f ${www_path}/config/nginx.conf ] || \cp -f ${www_path}/config/nginx.conf ${www_path}/config/nginx.conf.$(F_DATE)
    [ ! -f /etc/init.d/nginx ] || \cp -f /etc/init.d/nginx /etc/init.d/nginx.$(F_DATE)

    \cp -f ${cfg_path}/nginx/nginx.conf ${www_path}/config/nginx.conf && \
        \cp -f ${cfg_path}/nginx/nginx.init /etc/init.d/nginx && \
        sed -i -e 's#@nginxdir@#'${resty_dst}/nginx'#' -e 's#@vardir@#'${resty_var}'#' -e 's#@wwwdir@#'${www_path}'#' ${www_path}/config/nginx.conf && \
        sed -i -e 's#@nginxdir@#'${resty_dst}/nginx'#' -e 's#@vardir@#'${resty_var}'#' -e 's#@workdir@#'${www_path}'#' /etc/init.d/nginx && \
        chmod +x /etc/init.d/nginx
    F_LOG_EXIT " RESTY CONFIG 修改配置 " ${log_file}
    
    ## 创建目录
    mkdir -p ${resty_var}/log && mkdir -p ${resty_var}/run && chown www:www -R ${resty_var} && chown www:www -R ${www_path}
    F_LOG_EXIT " RESTY CONFIG 创建目录 " ${log_file}
    
    ## 启动 nginx
    chmod +x /etc/init.d/nginx && service nginx restart && update-rc.d nginx defaults
    #F_LOG_EXIT " RESTY START " ${log_file}

    F_SAVE_STEP "INSTALL RESTY" ${step_file}
}

function install_luarocks
{
    F_CHECK_STEP "INSTALL LUAROCKS" ${step_file} && { F_LOG_SUCCESS " LUAROCKS 已安装 " ${log_file}; return 0;}
    
    f_cd_tar luarocks-2.2
    local rocks_src=$(pwd)
    local rocks_dst=${opt_path}/luajit
    
    ./configure --prefix=${rocks_dst} --with-lua=${rocks_dst} --with-lua-include=${rocks_dst}/include/luajit-2.1 --lua-suffix=jit && \
    make build && make install
    F_LOG_EXIT " LUAROCKS INSTALL " ${log_file}
    
    luarocks install luafilesystem
    F_LOG_EXIT " LUAROCKS INSTALL luafilesystem " ${log_file}

    F_SAVE_STEP "INSTALL LUAROCKS" ${step_file}
}

function install_redis
{
    F_CHECK_STEP "INSTALL REDIS" ${step_file} && { F_LOG_SUCCESS " REDIS 已安装 " ${log_file}; return 0;}
    
    f_cd_tar redis-3.0
    local redis_src=$(pwd)
    local redis_dst=${opt_path}/redis
    local redis_var=${var_path}/redis
    
    make && mkdir -p ${redis_dst}/bin && \
    cp -prf ${redis_src}/src/redis-server ${redis_dst}/bin/ && \
    cp -prf ${redis_src}/src/redis-sentinel ${redis_dst}/bin/ && \
    cp -prf ${redis_src}/src/redis-cli ${redis_dst}/bin/ && \
    chmod +x ${redis_dst}/bin/*
    F_LOG_EXIT " REDIS INSTALL " ${log_file}
    
    f_add_bin_path "${redis_dst}/bin"
    
    \cp -f ${cfg_path}/redis/redis.conf ${redis_dst}/redis.conf && \
        \cp -f ${cfg_path}/redis/redis.init /etc/init.d/redis && \
        sed -i -e 's#@redisdir@#'${redis_dst}'#' -e 's#@vardir@#'${redis_var}'#' ${redis_dst}/redis.conf && \
        sed -i -e 's#@redisdir@#'${redis_dst}'#' -e 's#@vardir@#'${redis_var}'#' /etc/init.d/redis && \
        chmod +x /etc/init.d/redis
    F_LOG_EXIT " REDIS CONFIG 修改配置 " ${log_file}
    
    \cp -f ${cfg_path}/redis/60-redis-sysctl.conf /etc/sysctl.d/ && sysctl -p && service procps start
    F_LOG_EXIT " REDIS CONFIG 优化配置 " ${log_file}
    
    if ! grep -q "echo never > /sys/kernel/mm/transparent_hugepage/enabled" /etc/rc.local; then
        echo never > /sys/kernel/mm/transparent_hugepage/enabled
        echo "echo never > /sys/kernel/mm/transparent_hugepage/enabled" >> /etc/rc.local
    fi
    
    ## 创建目录
    mkdir -p ${redis_var}/log && mkdir -p ${redis_var}/run && mkdir -p ${redis_var}/rdb && chown www:www -R ${redis_var}
    F_LOG_EXIT " REDIS CONFIG 创建目录 " ${log_file}
    
    ## 启动 redis
    chmod +x /etc/init.d/redis && service redis restart && update-rc.d redis defaults
    F_LOG_EXIT " REDIS START " ${log_file}

    F_SAVE_STEP "INSTALL REDIS" ${step_file}
}

###############################################################################################

source ./util.sh

MAKE_J=8

data_path=/data
opt_path=${data_path}/opt
log_path=${data_path}/log
tmp_path=${data_path}/tmp
var_path=${data_path}/var
www_path=${data_path}/www

init_path=$(pwd)
cfg_path=${init_path}/cfg
pkg_path=${init_path}/pkg

mkdir -p ${data_path}
mkdir -p ${opt_path}
mkdir -p ${log_path}
mkdir -p ${tmp_path}/init
mkdir -p ${var_path}
mkdir -p ${www_path}/config
mkdir -p ${www_path}/server

log_file=${log_path}/init.log
step_file=${log_path}/init.step

host_name=''
time_zone='Asia/Shanghai'

while getopts h:t:n: opt; do
     case "$opt" in
         h) host_name=$OPTARG ;;
         *) f_print_help; exit 1 ;;
     esac
done

if [[ -z "${host_name}" ]]; then
    f_print_help; exit 1
fi

F_LOG_EXIT " 检查参数 ${host_name} " ${log_file}

install_base

checkout_reps

download_pkgs

install_php

install_openresty

install_luarocks

install_redis

chown www:www -R ${www_path}



