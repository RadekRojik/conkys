#! /usr/bin/env bash

# ###################################################################
# ###################################################################
#     conkys_start.sh
# ###################################################################
# ###################################################################


DISK=$1
MY_PID=$$


# ###################################################################
# Some functions

Dotaz () {
  smartctl -l scttempsts -n standby --json=g -d $TYPE /dev/$DISK
}

# fce invoke switch to standby mode
Uspi () {
  smartctl -s standby,now -d $TYPE /dev/$DISK
  echo "$(date +'%F %T') $DISK switch to standby mode" >> "$LOG"
}

# Prepare awk question with deleting two type chars(;"). If succes return 0 otherwise 1
ptam_se () {
awk /"$co"/'{sub(";","",$3); gsub("\"","",$3); print $3; konec=1}; END {exit !konec}'
}

# _____________________________________________________________________________


# ###################################################################
# clearing after kill
trap vycisteni 1 3 9 exit
# trap "echo 'jedu dál'" SIGCONT


# ###################################################################
# funtion invoke customed termination with message
exit_script () {
  echo "$(date +'%F %T') $DISK terminated: $1" >> "$LOG"
  exit $2
}

# Viktor cleaner
vycisteni () {
  # catch exit code
  UNSER_FEHLER=$?
  # remove own directory
  rm -fr $OPERATIVNI_DIR/$DISK && echo "$(date +'%F %T') $DISK was disconnect and directory removed" >> "$LOG"
  # return exit code
  return $UNSER_FEHLER
}


# ##############################################################################
# read config script
source


# ##############################################################################
# create directory `conkys`
[ -d $OPERATIVNI_DIR ] || mkdir $OPERATIVNI_DIR
mkdir $OPERATIVNI_DIR/$DISK || exit_script "Error creating directory $OPERATIVNI_DIR/$DISK" 1
# Create PID file content PID of this script
echo $MY_PID > $OPERATIVNI_DIR/$DISK/PID


# ##############################################################################
# First of all, read serial number HD
co="json.serial_number"
# If it's not serial number -> error
SERIAL_NUM=`ptam_se <<< $(smartctl -i --json=g /dev/$DISK)` || exit_script "can not read info about serial number from S.M.A.R.T" 1


# Fn question about device type
fn_type () {
co="json.device.type"
TYPE=`ptam_se <<< $(smartctl -i --json=g /dev/$DISK)` || exit_script "can not read info about device type" 1
}


# -----------------------------------------------------------------------
# Ignoring disk | TYPE disk | serial number | sleep after | read timeout | treshold | arguments for smartctl
# -----------------------------------------------------------------------
# rotation=$(cat /sys/block/$DISK/queue/rotational) || exit 1


# Fn prepare variables with values from database otherwise from default values
fn_cteni_promennych () {
  ignorovat="0"
  [[ $disk_type ]] && TYPE=$disk_type || fn_type 
  [[ $disk_uspani ]] && SPAT_ZA=$disk_uspani
  [[ $disk_rychlost ]] && LOOP_DELAY=$disk_rychlost
  # Setting threshold
  # If fails read threshold with first pass, wake up HD and read one more time.
  # If second pass fails, exit with error
  [[ $disk_treshold ]] && TRESHOLD=$disk_treshold || ( fn_treshold || fn_treshold )
}


fn_treshold () {
fn_type
# Read how many 'reads' HD has
read TR zbytek < <(cat /sys/block/$DISK/stat 2> /dev/null) || exit_script "can not read stat file" 1
# Prepare question
co="json.temperature.current"
# Test if it is the first pass
if [[ $ERSTE_GANG ]]; then
  TEMP=`ptam_se <<< $(Dotaz)` || exit_script "something is bad, can not read threshold" 1
  ERSTE_GANG=0
else
  TEMP=`ptam_se <<< $(Dotaz)` || CHYBA=1
  if [[ $CHYBA ]]; then
    # Wake up!!
    smartctl -A -d $TYPE /dev/$DISK > /dev/null
    ERSTE_GANG=1
    # I've a bit of the time
    sleep 1
  fi
fi
# Again read how many 'reads' are from HD stat file
read TR1 zbytek < <(cat /sys/block/$DISK/stat 2> /dev/null) || exit_script "can not read stat file" 1
# Diference between reads make our own threshold
TRESHOLD=$(( $TR1-$TR ))
return $ERSTE_GANG
}


# ##############################################################################
# Loading data from database
# UNBEKANNT=
while read -r radek; do
  IFS=\| read -r ignorovat disk_type disk_seriak disk_uspani disk_rychlost disk_treshold argumenty < <(sed 's/^[ ]*//; s/[ ]*|/|/g; s/|[ ]*/|/g; s/[ ]*$//' <<< "$radek")
  # line begining with hash ignores it -> it is comment
  [ "$ignorovat" = "\#*" ] && continue
  # Comparing HD with database. If it does not match serial number, go to next line
  [ "$disk_seriak" != "$SERIAL_NUM" ] && continue
  # From this point we have disk in database
  [ "$ignorovat" = "1" ] && exit_script "is ignored" 0
  fn_cteni_promennych
  [[ $argumenty ]] && smartctl $argumenty -d $TYPE /dev/$DISK
  UNBEKANNT=1
  break
  echo "$(date +'%F %T') $radek" >> "$LOG"
done < "$konfigurak"


# ##############################################################################
# If HD isn't defined, this is going to add them in database
if [[ ! $UNBEKANNT ]]; then
  fn_treshold || fn_treshold
  echo "$(date +'%F %T') New disk has been added to database:" >> "$LOG"
  echo "$ignorovat|$TYPE|$SERIAL_NUM|$SPAT_ZA|$LOOP_DELAY|$TRESHOLD|" >> "$LOG"
  echo "$ignorovat|$TYPE|$SERIAL_NUM|$SPAT_ZA|$LOOP_DELAY|$TRESHOLD|" >> "$konfigurak"
fi


# ##############################################################################
# fn read temperature from S.M.A.R.T and write it in temp file.
# Exit status from smartctl shows if HD is in standby mode
fn_temp () {
ACT=$ACTIVE
ACTIVE=0
read TR zbytek < <(cat /sys/block/$DISK/stat 2> /dev/null)
co="json.temperature.current"
TEMP=`ptam_se <<< $(Dotaz)` && ACTIVE=1
[ $TEMP ] && echo $TEMP > $OPERATIVNI_DIR/$DISK/temp
echo $ACTIVE > $OPERATIVNI_DIR/$DISK/activity
[ $ACT -ne $ACTIVE ] && echo "$(date +'%F %T') $DISK activity has been switched from $ACT into $ACTIVE" >> "$LOG"
}


# initilization of variables
ACTIVE=1
pocatecni_cas=$(date +%s)
TR1=0
echo "$(date +'%F %T') $DISK started" >> "$LOG"


# ##############################################################################
# main loop
# ##############################################################################

while :; do
  sleep $LOOP_DELAY
  fn_temp
# *****************************************************************
# Line below should be commented to normal traffic. This write current status in log file
# with the same name with suffix 'is' beside our own log file
#  echo "$(date +'%F %T'): $DISK temperatur: "`cat $OPERATIVNI_DIR/$DISK/temp`" °C activity: `cat $OPERATIVNI_DIR/$DISK/activity`" > "$LOG"is

  # HD is sleeping, get back at beggining
  [ $ACTIVE -eq 0 ] && continue
  
  # if threshold is bigger than our own default, downcount again
  [ $(( $TR - $TR1 )) -gt $TRESHOLD ] && pocatecni_cas=$(date +%s)
  
  # HD timeout, go to sleep (switch to standby mode)
  [ $(( $pocatecni_cas + $SPAT_ZA )) -lt $(date +%s) ] && Uspi
  
  # clear reads
  TR1=$TR
done
