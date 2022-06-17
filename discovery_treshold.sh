#! /usr/bin/env bash

# ###################################################
# skript přijímá dva parametry a to název disku a
# typ disku podle `smartctl -d test /dev/testovany_disk`
# Pokud není druhý argument zadán je použit typ `sat`
# příklad spuštění:
#
# sudo disk_treshold.sh sdb sat
#
# ###################################################

# $$ - vlastní pid

# načtení názvu disku z argumentu skriptu
ktery_disk=$1

# načtení type disku. Když je argument prázdný
# nastaví se type na `sat`
type_disku=${2-'sat'}

# kolikrát má proběhnout testovací vzorek
# čím vyšší číslo, tím přesnější
pocet_cyklu=100
cyklu=$pocet_cyklu


# načtem kolik proběhlo operací read před našim testem
poc_sektoru=$( awk {'print $1'} /sys/block/$ktery_disk/stat 2> /dev/null ) || exit 1

# smyčka o zadaném počtu cyklů
while [ "$pocet_cyklu" -gt 0 ]; do

  # načtem a zobrazíme teplotu z disku
  awk '/json.temperature.current/{sub(";", "°C", $NF); print $NF}' <<< `smartctl -l scttempsts --json=g -d $type_disku /dev/$ktery_disk`


  # dekrementace cyklu
  pocet_cyklu=$(( $pocet_cyklu - 1 ))
done

# kolik readů po testu
kon_sektoru=$( awk {'print $1'} /sys/block/$ktery_disk/stat 2> /dev/null ) || exit 1

# rozdíl v počtu readů

rozdil=$(( $kon_sektoru - $poc_sektoru ))
echo "start sektoru: $poc_sektoru | end sektoru: $kon_sektoru | rozdíl: $rozdil"
echo "Jeden read (treshold) = $(( $rozdil / $cyklu ))"
