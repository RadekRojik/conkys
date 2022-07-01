#! /usr/bin/env bash

# ###################################################################
# ###################################################################
#
# Skript je spouštěn pomocí `udev` a `systemd`
# Přijme od `udev` jen cestu s názvem připojeného disku
# Vytvoří v RAM/SWAP prostoru virtuální adresář se
# soubory `temp`, `activity` a `PID`:
# /dev/shm/conkys/nazev_disku/temp
# /dev/shm/conkys/nazev_disku/activity
# /dev/shm/conkys/nazev_disku/PID
# soubor `temp` obsahuje jen `int` teplotu v "tisícinách" stupních Celsia
# "tisíciny" jen kvůli kompatibilitě s hwmon specifikací
# soubor `activity` obsahuje jen booleovskou hodnotu.
# Pokud bude hodnota `1` je disk aktivní a soubor `temp` je aktuální
# Pokud bude `0` tak je disk ve standby režimu a teplota bude poslední
# hodnota která byla aktivní.
# Soubor `PID` obsahuje pid obslužného scriptu. Při odpojení disku
# udev zavolá script, který dotyčný autonom.sh killne a smaže větev v adresáři
# Skript přijímá jediný argument a to /cesta/název disku
# vše ostatní z databáze /etc/conky/conkys.conf nebo testu a defaultu
# test na platnost disku nebudu dělat. Protože skript bude spouštět
# udev s root právy. A při testování si musí dát tester bacha
# ###################################################################
# ###################################################################

# ###################################################################
# TODO:
# *
# nvme disky budou automaticky registrovány systémem v dir `hwmon`
# při detekci takového disku, skript vytvoří softlink ze
# /sys/block/nazev_disku/device/device/hwmon/hwmon*/temp1_input
# na
# /dev/shm/conky/nazev_disku/temp
# a v
# /dev/shm/conky/nazev_disku/activity
# bude stále hodnota `1`
# Ve smyčce bude jen kontrola platnosti linku. Jakmile bude
# neplatný (disk je odebrán), smaže dotyčný adresář a ukončí se.
#
# *
# Asi přidat náhodné probuzení a vzápětí uspání disku kvůli aktuální teplotě


DISK=$1


# ###################################################################
# pár pomocných funkcí

Dotaz () {
  smartctl -l scttempsts -n standby --json=g -d $TYPE /dev/$DISK
}

# fce uspání disku
Uspi () {
  smartctl -s standby,now -d $TYPE /dev/$DISK
  echo "$(date +'%F %T') $DISK přepínám do standby" >> "$LOG"
}

# fce předpřipraveného awk. Vrátí buď výsledek bez středníku a uvozovek,
# nebo chybový výstup při nenalezení.
ptam_se () {
awk /"$co"/'{sub(";","",$3); gsub("\"","",$3); print $3; konec=1}; END {exit !konec}'
}

# _____________________________________________________________________________


# ###################################################################
# nastavení záchytu špatných signálů
MY_PID=$$
# echo "můj PID: $MY_PID"
trap vycisteni 1 3 9 exit
trap "echo 'jedu dál'" SIGCONT


# ###################################################################
# fce volaná při vyvolaném ukončení skriptu
ukonceni_skriptu () {
  # custom vyvolání chybového hlášení a chyby
  # echo $'\nkončím!!\n'"$1" >> "$LOG"
  echo "$(date +'%F %T') $DISK končím: $1" >> "$LOG"
  exit $2
}

# Viktor čistič - totální úklid při ukončení/zabití skriptu
vycisteni () {
  # Kód chyby je třeba hned zachytit
  # jinak v něm bude návratová hodnota něčeho jiného
  UNSER_FEHLER=$?
  # echo $'\nchybka '"$UNSER_FEHLER"
  # smazání aktuálního adresáře
  # echo "$(date +'%F %T') $DISK byl odpojen a adresář smazán" >> "$LOG"
  rm -fr $OPERATIVNI_DIR/$DISK && echo "$(date +'%F %T') $DISK byl odpojen a adresář smazán" >> "$LOG"
  # skript skončí se správným chybovým
  # kódem předaným automaticky v rámci bash
  return $UNSER_FEHLER
}


# ##############################################################################
# načtení konfiguráku
source
# source /home/radek/.config/conky/conkys_data.conf.sh || ukonceni_skriptu "nelze načíst configurační soubor"


# ##############################################################################
# vytvoření příslušného adresáře `conkys`
[ -d $OPERATIVNI_DIR ] || mkdir $OPERATIVNI_DIR
mkdir $OPERATIVNI_DIR/$DISK || ukonceni_skriptu "chyba při vytváření adresáře $OPERATIVNI_DIR/$DISK" 1
# vytvoření PID souboru s PIDem skriptu
echo $MY_PID > $OPERATIVNI_DIR/$DISK/PID


# ##############################################################################
# podle serial number se zkusí vyhledat disk v databazi
co="json.serial_number"
# prohledani databaze
SERIAL_NUM=`ptam_se <<< $(smartctl -i --json=g /dev/$DISK)` || ukonceni_skriptu "nelze načíst info o sériovém čísle disku za SMARTu" 1


# Pokud se nic v db nenašlo automaticky se tam disk přidá a 
# příště by měl být start skriptu rychlejší. Pak si může uživatel doupravit
# parametry v databázi
fn_type () {
co="json.device.type"
TYPE=`ptam_se <<< $(smartctl -i --json=g /dev/$DISK)` || ukonceni_skriptu "nelze načíst informace o typu device" 1
}


# -----------------------------------------------------------------------
# TYPE disku | sériové číslo | doba uspání | rychlost kontroly | treshold
# -----------------------------------------------------------------------
# rotation=$(cat /sys/block/$DISK/queue/rotational) || exit 1


fn_cteni_promennych () {
  # pokud je TYPE v databazi načti to, jinak vygeneruj z dotazu.
  [[ $disk_type ]] && TYPE=$disk_type || fn_type 
  # pokud je nastaveno disk_uspani přebere se to, jinak nastavit default.
  [[ $disk_uspani ]] && SPAT_ZA=$disk_uspani
  # nastavení rychlosti smyčky
  [[ $disk_rychlost ]] && LOOP_DELAY=$disk_rychlost
  # nastavení tresholdu
  # pokud selže průchod na načtení automatického tresholdu probudí se disk a 
  # zkusí se to ještě jednou. Při dalším selhání se skript ukončí
  [[ $disk_treshold ]] && TRESHOLD=$disk_treshold || ( fn_treshold || fn_treshold )
}


fn_treshold () {
fn_type
# Přečtou se ready ze statu disku
read TR zbytek < <(cat /sys/block/$DISK/stat 2> /dev/null) || ukonceni_skriptu "nelze přečíst stat" 1
# Ptát se bude na teplotu
co="json.temperature.current"
# Test na první průchod
if [[ $ERSTE_GANG ]]; then
  TEMP=`ptam_se <<< $(Dotaz)` || ukonceni_skriptu "něco je bad, nemůžu přečíst treshold" 1
  ERSTE_GANG=0
else
  TEMP=`ptam_se <<< $(Dotaz)` || CHYBA=1
  if [[ $CHYBA ]]; then
    # vstávej semínko holala...
    smartctl -A -d $TYPE /dev/$DISK > /dev/null
    ERSTE_GANG=1
    # Dá se tomu chvilku čas
    sleep 1
  fi
fi
# Znova se přečtou ready ze statu disku
read TR1 zbytek < <(cat /sys/block/$DISK/stat 2> /dev/null) || ukonceni_skriptu "nelze přečíst stat" 1
# rozdíl počtu readů je náš treshold
TRESHOLD=$(( $TR1-$TR ))
return $ERSTE_GANG
}


# ##############################################################################
# načtení dat z databáze
# UNBEKANNT=
while read -r radek; do
  IFS=\| read -r disk_type disk_seriak disk_uspani disk_rychlost disk_treshold < <(sed 's/ //g; s/\t//g' <<< "$radek")
  # řádek začínající hashtagem ignorovat. Je to komentář.
  [[ $disk_type = \#* ]] && continue
  # porovnání disku s databází. Pokud se neschoduje sériové číslo, přejdi na další řádek
  [[ $disk_seriak != $SERIAL_NUM ]] && continue
  # zde už jen pokud máme disk v databázi
  fn_cteni_promennych
  UNBEKANNT=1
  break
  echo "$(date +'%F %T') $radek" >> "$LOG"
done < "$konfigurak"


# ##############################################################################
# Pokud je disk neznámý, zapíše se do databáze s vypočítaným tresholdem.
# V databázi se dají jednoduše různé parametry lépe donastavit. A příště bude
# disk s těmito parametry načten
if [[ ! $UNBEKANNT ]]; then
  fn_treshold || fn_treshold
  echo "$TYPE|$SERIAL_NUM|$SPAT_ZA|$LOOP_DELAY|$TRESHOLD" >> "$konfigurak"
fi


# ##############################################################################
# funkce na načítání a zápis teploty a aktivity
fn_temp () {
ACT=$ACTIVE
ACTIVE=0
read TR zbytek < <(cat /sys/block/$DISK/stat 2> /dev/null) # || ukonceni_skriptu "nelze přečíst stat, asi je odpojen disk" 1
co="json.temperature.current"
TEMP=`ptam_se <<< $(Dotaz)` && ACTIVE=1
[ $TEMP ] && echo $TEMP > $OPERATIVNI_DIR/$DISK/temp
echo $ACTIVE > $OPERATIVNI_DIR/$DISK/activity
[ $ACT -ne $ACTIVE ] && echo "$(date +'%F %T') $DISK změna aktivity z $ACT na $ACTIVE" >> "$LOG"
}


# inicializace proměnných
ACTIVE=1
pocatecni_cas=$(date +%s)
TR1=0
echo "$(date +'%F %T') $DISK spouštím" >> "$LOG"
# ##############################################################################
# hlavní smyčka
# ##############################################################################

while :; do
  # date
  sleep $LOOP_DELAY
  fn_temp
# *****************************************************************
# následující řádek na ostrý provoz zakomentovat
#  echo "$(date +'%F %T'): $DISK teplota: "`cat $OPERATIVNI_DIR/$DISK/temp`" °C aktivní: `cat $OPERATIVNI_DIR/$DISK/activity`" > "$LOG"is

  # Když je disk neaktivní přeskoč to
  [ $ACTIVE -eq 0 ] && continue
  
  # aktivita na disku je větší než treshold, začni odpočet času od začátku
  [ $(( $TR - $TR1 )) -gt $TRESHOLD ] && pocatecni_cas=$(date +%s)
  
  # pokud se překročí čas, přepnem do standby
  [ $(( $pocatecni_cas + $SPAT_ZA )) -lt $(date +%s) ] && Uspi
  
  # "vynulování" readů
  TR1=$TR
done
