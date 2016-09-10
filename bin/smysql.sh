#!/bin/bash

set -e

declare -ra ARGS=( ${@} )
declare -ri ARGV=${#ARGS}
declare -rA ALIASES=(
  [smysql]=mysql
  [smysqldump]=mysqldump
  [smydumper]=mydumper
  [smyisamchk]=myisamchk
  [smyloader]=myloader
  [smysqladmin]=mysqladmin
  [smysqlanalyze]=mysqlanalyze
  [smysqlcheck]=mysqlcheck
  [smysqlimport]=mysqlimport
  [smysqloptimize]=mysqloptimize
  [smysqlpump]=mysqlpump
  [smysqlrepair]=mysqlrepair
  [spt-show-grants]=pt-show-grants
  [spt-table-checksum]=pt-table-checksum
  [spt-table-sync]=pt-table-sync
  [spt-query-digest]=pt-query-digest
  [spt-archiver]=pt-archiver
  [spt-find]=pt-find  
  [spt-config-diff]=pt-config-diff
  [spt-deadlock-logger]=pt-deadlock-logger
  [spt-duplicate-key-checker]=pt-duplicate-key-checker
  [spt-fk-error-logger]=pt-fk-error-logger
  [spt-heartbeat]=pt-heartbeat
  [spt-index-usage]=pt-index-usage
  [spt-kill]=pt-kill
  [spt-mysql-summary]=pt-mysql-summary
  [spt-online-schema-change]=pt-online-schema-change
  [spt-osc]=pt-online-schema-change
  [spt-slave-delay]=pt-slave-delay
  [spt-slave-find ]=pt-slave-find
  [spt-slave-restart]=pt-slave-restart
  [spt-stalk]=pt-stalk
  [spt-upgrade]=pt-upgrade
  [spt-variable-advisor]=pt-variable-advisor
  [spt-visual-explain]=pt-visual-explain

)
declare -r PROGNAME=$(basename ${0})
declare -r SEC_MYCNF=$(test -f ${1:-undef} && echo $_ || echo 'my.gpg')
declare -r SEC_FIFO=$(mktemp)
declare -r PASSTHRU=${ARGS[@]:$(test -f ${1:-undef} && echo 1 || echo 0)}

set -u

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
    local realfn=$(realpath ${0})
    cat <<EOS | fold -sw 120
USAGE: $(basename ${0}) enc_file.gpg [--arg=val]

use a GPG-encrypted my.cnf (default: ${SEC_MYCNF})

currently supports:
${ALIASES[@]}

create a symlink to match the alias (real app prefixed with 's')
e.g.

sudo ln -s ${realfn} /usr/local/bin/smysql
sudo ln -s ${realfn} /usr/local/bin/spt-show-grants

EOS
}

trap cleanup EXIT

test -e ${SEC_MYCNF} || { usage; exit 1; }
cmd=$(check_cmd ${PROGNAME})
test $? -eq 0 || { echo ${ALIASES[${PROGNAME}]} is not available; exit 3; }

cleanup && mkfifo ${SEC_FIFO} && decrypt &
exec_cmd ${cmd} ${PASSTHRU[@]}
