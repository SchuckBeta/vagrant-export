#!/usr/bin/env bash -eu

DIRECTORY=$1
TOTAL_SIZE=$2
TARGET_TAR=$3
FILES_LIST=$4

cd ${DIRECTORY}
tar -C ${DIRECTORY} -c ${FILES_LIST} | pv -f -n -s ${TOTAL_SIZE} | gzip -c > ${TARGET_TAR}
