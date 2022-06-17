#! /usr/bin/env bash

# *******************************************************
# skript má za úkol sledovat aktivitu na disku
# od poslední aktivity po nastaveném čase přepne disk
# do standby módu. Skript vyžaduje smartctl (i starší verze).
# Lepší je skript spouštět s root právy. Nebo mít v .sudoers
#  a .bash_aliases nastaveno bezheslové spouštění smartctl
# zatím se skript spouští růčo:
# disk_handle.sh sdb &
# kde sdb je disk který chcete tímto způsobem "kontrolovat"
# pokud je někdo zvědavý ať si na konci skriptu odkomentuje
# označené řádky.V tom přídě se skript spustí bez posledního znaku &
# disk_handle.sh sdb
# alternativní spuštění:  
# disk_handle.sh sdb 900
# kde 900 je čas v sekundách za jak dlouho se má disk přepnout
# přednastavený čas je na 10minut
#********************************************************
# TODO:
# * automatická detekce typu disku -- hotovo
# * optimalizace na výkon
# * automatická detekce tresholdu
# *******************************************************

# #######################################################
# #######################################################
# Tady se dají vcelku bezproblémově nastavit různé
# parametry:


# po jaké době se má uspat disk v sekundách
m_sleep='600'

# rychlost hlavního loopu v sekundách
# čím vyšší číslo tím více šetříme CPU
# na úkor rychlosti odezvy
m_loop='2'

# defaultní treshold
treshold='2'

# #######################################################
# #######################################################
# a odtud už jen s velkou opatrností

# pomocná proměnná
NAS_READ='0'

# argumenty a jejich pořadí
# * první bude disk!
# * doba na uspání disku v sekundách
# * treshold
# * jak rychlý má být loop

# načtem název disku z prvního argumentu
m_disk=$1

# test jestli existuje soubor rotational
# pokud neexistuje, máme špatně zadaný disk nebo neexistuje
# když existuje jeho obsah předáme do proměnné rotation
# v opačném případě se skript ukončí s nenulovou návratovou hodnotou
rotation=$(cat /sys/block/$m_disk/queue/rotational) || exit 1

# pokud má předchozí výsledek hodnotu 0 disk by měl
# být bezplotnový a ukončíme to protože bezplotnové
# disky se neuspávají
# Zde se může vyskytnout problém. Třeba jedna prehistorická
# USB klíčenka (512MB = to bylo tenkrát dělo :D ) je registrována v
# systému jako plotnový disk. Nicméně smartctl ji nedokáže zpracovat
# a končí chybou
# pokud si je někdo jist, že disk je plotnový a jen se špatně
# registruje, ať zakomentuje následující řádek
[[ $rotation -ne 0 ]] || exit 0

# detekce typu disku
TYPE=$(awk /json.device.type/{'sub("\"","",$NF);sub("\"\;","",$NF); print $NF'} <<< `smartctl --json=g -d test /dev/sda`)

# vytvoříme si vlastní konstrukt příkazu na uspávání
uspavadlo="smartctl -s standby,now -d $TYPE"
kontrola_stavu="smartctl -l scttempsts -d $TYPE"

# přiřazení argumentů. Pokud nejsou zadány nastavíme je do defaultu
m_sleep=${2-$m_sleep}
m_loop=${4-$m_loop}
treshold=${3-$treshold}

# #######################################################
# zde budou funkce

## pomocná funkce na výpisy
hlaska () {
  cat <<LOG_HLASKA
  -----------------------------------------------
  stand: $STANDBY
  treshold: $treshold
  počáteční čas: $pocatecni_cas
  aktuální čas $(date +%s)
LOG_HLASKA
}


# #######################################################

# předregistrace časového razítka aby se disk neposlal hned spát
pocatecni_cas=$(date +%s)

# místo `true` dáme dvojtečku, ušetříme tím strojový čas
while :;do

  # načtem hodnotu read. Pokud bude návratová hodnota nenulová
  # disk už není připojen a ukončí se to
  TR=$(awk {'print $1'} /sys/block/$m_disk/stat) || exit 0

# později proměnnou zakomentovat nebo vymazat ať nezabírá paměť
  nespi='Disk je ve standby módu'
# *************************

  # test jestli disk spí
  if [ "$STANDBY" ]; then
    # disk nespííí

# později proměnnou zakomentovat nebo vymazat ať nezabírá paměť
    nespi='Disk je aktivní'
# *************************

    if [ $(( $TR - $NAS_READ )) -gt $treshold ]; then
      # pokud jsme mimo treshold nastavujem časové razítko
      # $TR - $NAS_READ  spočítá kolik proběhlo na daném
      # disku čtecích operací za jeden cyklus
      # pokud je to více než treshold nastaví se nové časové razítko
      pocatecni_cas=$(date +%s)

# později proměnnou zakomentovat nebo vymazat ať nezabírá paměť
      nespi='startuji časové razítko od teď za $m_sleep sekund se přejde \
      do standby módu pokud se disk nebude používat'
# *************************

    else
      # jsme v rámci tresholdu
      # porovnáme časové razítko s aktuálním časem
      # pokud je překročen časový limit přepnem disk do standby módu
      [ $(( $pocatecni_cas + $m_sleep )) -lt $(date +%s) ] && $uspavadlo /dev/$m_disk
    fi
  fi

  # Tohle vlastně není nutné! To by neměla být práce tohoto scriptu
  # načtem informace ze S.M.A.R.T.u disku
  # SMART=$(sudo smartctl -l scttempsts -d $typ /dev/$m_disk)
  # STANDBY=$(echo "$SMART" | grep -i 'device state' | cut -d '(' -f 2)
  # Tohle se mi nedaří lépe napsat aniž by to přestalo fungovat ;(
  # STANDBY=`sudo $kontrola_stavu /dev/$m_disk | grep -i 'active'` 
  # Takhle to vypadá, když hlava stárne a zapomíná...
  # Takže ÁÁÁÁÁ už to mám :D
  STANDBY=$(grep -i 'active' <<< `$kontrola_stavu /dev/$m_disk`)


  # uložíme si starou hodnotu na pozdější porovnání
  NAS_READ=$TR

# ***********************************************************************
  # výpis stavů různých proměnných.
  # Následující dva řádky odkomentovat jen na testy:
  hlaska
  echo $nespi
# ***********************************************************************

sleep $m_loop
done

