#!/bin/bash
#===============================================================================
#
#          FILE: util.sh
#
#         USAGE: source util.sh
#
#   DESCRIPTION: 全局函数
#
#        AUTHOR: xx
#       CREATED: 2013/10/24 22:05
#===============================================================================

set -o nounset                              # Treat unset variables as an error

function F_REAL_DIR
{
    echo $(dirname `/usr/sbin/lsof -p $$ | gawk '$4 =="255r"{print $NF}'`)
}

function F_DATE
{
    date +"%Y%m%d%H%M%S"
}

function F_LOCK
{
    local lock=1
    set -o noclobber
    if (echo "$$" > "$1" 2>/dev/null); then
        lock=0
        set +u
        local foo=''
        [ ""x == "$2"x ] || foo="$2 $1;"
        trap "$foo ret=$?; rm -f $1; exit ${ret};" INT TERM EXIT
        set -u
    fi
    set +o noclobber
    return ${lock}
}

function F_UNLOCK
{
    trap '' INT TERM EXIT
    rm -f "$1"
}

function F_FILE_MD5
{
    md5sum ${1} | gawk '{print $1}'
}

function F_CHECK_STEP
{
    [ -f "${2}" ] && cat ${2} | grep -qE "${1}"
}

function F_SAVE_STEP
{
    ! F_CHECK_STEP "${1}" "${2}" && echo "$(F_DATE) ${1}" >> ${2}
}

function F_PRINT_HELP
{
    echo -e "\033[1;31m ${1} \033[0m \n"
}

function F_PRINT_SUCCESS
{
    echo -e "[\033[1;32m OK \033[0m] $(F_DATE) ${1}"
}

function F_PRINT_ERROR
{
    echo -e "[\033[1;31mFAIL\033[0m] $(F_DATE) ${1}"
}

function F_LOG_SUCCESS
{
    F_PRINT_SUCCESS "${1}"
    echo "[ OK ] $(F_DATE) ${1}" >> ${2}
}

function F_LOG_ERROR
{
    F_PRINT_ERROR "${1}"
    echo "[FAIL] $(F_DATE) ${1}" >> ${2}
}

function F_MUTE_SUCCESS
{
    echo "[ OK ] $(F_DATE) ${1}" >> ${2}
}

function F_MUTE_ERROR
{
    echo "[FAIL] $(F_DATE) ${1}" >> ${2}
}

function F_PRINT
{
    if [ 0 == $? ]; then
        F_PRINT_SUCCESS "${1}"
    else
        F_PRINT_ERROR "${1}"
    fi
}

function F_PRINT_EXIT
{
    if [ 0 == $? ]; then
        F_PRINT_SUCCESS "${1}"
    else
        F_PRINT_ERROR "${1}"
        exit 1
    fi
}

function F_LOG
{
    local ret=$?

    if [ 0 == ${ret} ]; then
        F_LOG_SUCCESS "${1}" ${2}
    else
        F_LOG_ERROR "${1}" ${2}
    fi

    return ${ret}
}

function F_LOG_EXIT
{
    if [ 0 == $? ]; then
        F_LOG_SUCCESS "${1}" ${2}
    else
        F_LOG_ERROR "${1}" ${2}
        exit 1
    fi
}

function F_MUTE_EXIT
{
    if [ 0 == $? ]; then
        F_MUTE_SUCCESS "${1}" ${2}
    else
        F_MUTE_ERROR "${1}" ${2}
        exit 1
    fi
}
