#!/bin/bash

declare -ar ARGS=( ${@} )
declare -ri ARGV=${#ARGS}
declare -r SEC_MYCNF=${1:-my.gpg}
declare -r SEC_FIFO=$(mktemp)
declare -r PASSTHRU=${ARGS[@]:1}

function cleanup {
    test -f ${SEC_FIFO} && rm -f $_
    return $?
}

function decrypt {
    $(which gpg) --batch --yes -o ${SEC_FIFO} -d ${SEC_MYCNF} >debug.log 2>&1
    test $? -eq 0 || $(which gpg) -o ${SEC_FIFO} -d ${SEC_MYCNF} >debug.log 2>&1 
}

function mysql_connect {
    $(which mysql) --defaults-file=${SEC_FIFO} ${@}

}

trap cleanup EXIT

cleanup && mkfifo ${SEC_FIFO} && decrypt &
mysql_connect ${PASSTHRU}
