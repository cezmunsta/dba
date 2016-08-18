#!/bin/bash

set -eu

declare -ra ARGS=( ${@} )
declare -ri ARGV=${#ARGS}
declare -rA ALIASES=(
  [smysql]=mysql
  [sgrants]=pt-show-grants
  [schecksum]=pt-table-checksum
  [ssync]=pt-table-sync
  [sdigest]=pt-query-digest
)
declare -r PROGNAME=$(basename ${0})
declare -r SEC_MYCNF=$(test -f ${1:-undef} && echo $_ || echo 'my.gpg')
declare -r SEC_FIFO=$(mktemp)
declare -r PASSTHRU=${ARGS[@]:$(test -f ${1:-undef} && echo 1 || echo 0)}

function cleanup {
    test -e ${SEC_FIFO} && rm -f $_
    return $?
}

function decrypt {
    set +e
    $(which gpg) --batch --yes -o ${SEC_FIFO} -d ${SEC_MYCNF} >debug.log 2>&1
    test $? -eq 0 || $(which gpg) --yes -o ${SEC_FIFO} -d ${SEC_MYCNF} >debug.log 2>&1
    set -e
}

function check_cmd {
    local k
    local cmd=${1}

    for k in "${!ALIASES[@]}"; do
        test "${cmd}" = ${k} && \
          test -x "$(which ${ALIASES[${k}]})" && \
            echo $_ && return 0
    done

    return 1
}

function exec_cmd {
    local -r cmd=${1}
    local -a args=( ${@} )
    local -r passthru=${args[@]:1}

    ${cmd} --defaults-file=${SEC_FIFO} ${passthru[@]}
}

function usage {
    cat <<EOS | fold -sw 70
USAGE: $(basename ${0}) enc_file.gpg [--arg=val]

currently supports:
${ALIASES[@]}

EOS
}

trap cleanup EXIT

test -e ${SEC_MYCNF} || { usage; exit 1; }
cmd=$(check_cmd ${PROGNAME})
test $? -eq 0 || { echo ${ALIASES[${PROGNAME}]} is not available; exit 3; }

cleanup && mkfifo ${SEC_FIFO} && decrypt &
exec_cmd ${cmd} ${PASSTHRU[@]}
