#! /usr/bin/env bash

# This script make "game over"
source

# read PID process to be killed
PID=`cat $OPERATIVNI_DIR/$1/PID`

[ "$PID" = "" ] && echo "$(date +'%F %T') $1 do not exist" >> "$LOG" && exit 0

# send signal SIGTERM
kill $PID && echo "$(date +'%F %T') $1 process has been ended" >> "$LOG" || echo "$(date +'%F %T') unablle kill $1 with PID $PID" >> "$LOG"
