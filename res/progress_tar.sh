#!/usr/bin/env bash -eu

DIRECTORY=$1
TOTAL_SIZE=$2
TARGET_TAR=$3

tar -C ${DIRECTORY} -c ${DIRECTORY}/* | pv -n -s ${TOTAL_SIZE} | gzip -c > ${TARGET_TAR}
