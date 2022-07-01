#! /usr/bin/env bash

# skript na ukončení procesu
# Bude spouštěn pomocí `udev` při odpojení disku
# Při manuálním použití je nutno volat se sudo:
# sudo ukonci.sh disk
# kde `disk` je disk který byl odpojen

source

# Načte pid ovládacího procesu z jeho adresáře
# PID=`cat /dev/shm/conkys/$1/PID`
PID=`cat $OPERATIVNI_DIR/$1/PID`

# a zašle mu signál SIGTERM
kill $PID && echo "$(date +'%F %T') $1 proces byl ukončen" >> "$LOG" || echo "$(date +'%F %T') nelze zabít $1 s PID $PID" >> "$LOG"
