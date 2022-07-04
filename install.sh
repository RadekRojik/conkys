#! /usr/bin/env bash

# ##############################################################################
# Conkys install script. Runs only with root privilege!
# Without arguments:
# sudo install.sh
# Copies the scripts into their places. And enable daemons (udev and systemd)
# Script with '-u':
# sudo install.sh -u
# Purge the scripts from system and restart daemons.

# ##############################################################################
# Root test
[ $(id -u) -ne 0 ] && echo 'Only root can run it!!!' > /dev/stderr && exit 1

# Config directory
USER_DIR=/etc/conkys/
# Config files with basic settings
file1=conkys.conf.sh
file2=conkys_data.conf

if [ "-u" != "$1" ]; then

  # ##############################################################################
  # Test smartctl version. Less than 7.0 script will end with error
  # Json up to version 7.0 :
  # https://www.smartmontools.org/milestone/Release%207.0 
  MAJOR_VERZE=$(awk 'NR==1{/smartctl/; print $2}' <<< $(smartctl -V))
  # Hook due to bash aritmetic.
  MAJOR_VERZE=${MAJOR_VERZE//'.'/''}
  MAJOR_VERZE=${MAJOR_VERZE%%2}
  if [[ (( $MAJOR_VERZE -lt 70 )) ]]; then
    echo $'*** Error!!! ***\nToo less smartctl version!\nI need minimal 7.0' > /dev/stderr
    exit 1
  fi


  # #########################################################
  # Prepare config file
  co="OPERATIVNI_DIR="
  docasny_adr='/dev/shm/conkys'
  sed -i "s/$co$/$co${docasny_adr//\//\\/}/" $file1
  co="USER_DIR="
  sed -i "0,/$co$/s//$co${USER_DIR//\//\\/}/" $file1
  co="konfigurak="
  sed -i "0,/$co$/s//$co${USER_DIR//\//\\/}$file2/" $file1

  # #########################################################
  # prepare service scripts
  vklad="source $USER_DIR$file1 || exit_script 'unable read config file' 1"
  sed -i "0,/source$/s//${vklad//\//\\/}/1" conkys_start.sh
  vklad="source $USER_DIR$file1"
  sed -i "0,/source$/s//${vklad//\//\\/}/1" conkys_end.sh

  # create dir
  [ -d $USER_DIR ] || mkdir -m 777 $USER_DIR

  # copy files into their places
  install -o root -m 754 ./conkys_start.sh /usr/local/sbin/conkys_start.sh
  install -o root -m 754 ./conkys_end.sh /usr/local/sbin/conkys_end.sh
  install -o root -m 664 ./conkys@.service /etc/systemd/system/conkys@.service
  install -m 664 ./99-conkys.rules /etc/udev/rules.d/99-conkys.rules
  install -o root -m 754 ./$file1 $USER_DIR$file1
  install -m 664 ./$file2 $USER_DIR$file2

  # enable systemd service
  systemctl enable /etc/systemd/system/conkys@.service

else

  # uninstallation
  rm -f /usr/local/sbin/conkys_start.sh
  rm -f /usr/local/sbin/conkys_end.sh
  rm -f /etc/systemd/system/conkys@.service
  rm -f /etc/udev/rules.d/99-conkys.rules
  rm -f $USER_DIR$file1
  rm -f $USER_DIR$file2
  rm -fr $USER_DIR

fi

# reload rules and service
systemctl daemon-reload
udevadm control --reload-rules
udevadm trigger
