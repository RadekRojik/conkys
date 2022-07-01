#! /usr/bin/env bash


# ##############################################################################
# Instalační skript conkys. Musí být spuštěn s právy roota!
# Skript bez argumentu:
# sudo install.sh
# Nastaví proměnné, nakopíruje soubory na svá místa se správnýmy právy a
# spustí daemony/služby (udev a systemd) na pozadí.
# Skript s argumentem:
# sudo install.sh -u
# Odinstaluje soubory, zastaví a restartuje daemony/služby


# ##############################################################################
# test na root
[[ (( $(id -u) -ne 0 )) ]] && echo 'skript se musí spustit s root právy!!!' > /dev/stderr && exit 1


# #########################################################
# načtení jména běžného (základního) uživatele
uzivatel=$(id -n -u 1000)

# konfigurační adresář
USER_DIR=/home/$uzivatel/.config/conky
# konfigurační soubor se základním nastavením
file1=conkys_data.conf.sh
# konfigurak=$USER_DIR/my_conf.conf

if [[ $1 != "-u" ]]; then

# ##############################################################################
# Test na verzi smartctl. Při nižší verzi než 7.0 se skript ukončí
# Json je až od verze 7.0 zdroj:
# https://www.smartmontools.org/milestone/Release%207.0 
MAJOR_VERZE=$(awk 'NR==1{/smartctl/; print $2}' <<< $(smartctl -V))
# vifiku...ce kvůli bashové aritmetice.
MAJOR_VERZE=${MAJOR_VERZE//'.'/''}
MAJOR_VERZE=${MAJOR_VERZE%%2}
if [[ (( $MAJOR_VERZE -lt 70 )) ]]; then
  echo $'*** Chyba!!! ***\nNízká verze smartctl!\nMinimální doporučená verze je 7.0' > /dev/stderr
  exit 1
fi


# #########################################################
# Příprava konfiguračního souboru
co="OPERATIVNI_DIR="
docasny_adr='/dev/shm/conkys'
sed -i "s/$co$/$co${docasny_adr//\//\\/}/" $file1
co="USER_DIR="
sed -i "0,/$co$/s//$co${USER_DIR//\//\\/}/" $file1
za=$co${USER_DIR//\//\\/}

# #########################################################
# příprava hlavního scriptu
vklad="source $USER_DIR/$file1 || ukonceni_skriptu 'nelze načíst configurační soubor'"
sed -i "0,/source$/s//${vklad//\//\\/}/1" conkys_start.sh

# příprava ukončovacího skriptu
vklad="source $USER_DIR/$file1"
sed -i "0,/source$/s//${vklad//\//\\/}/1" conkys_end.sh

# kopírování souborů na svá místa s příslušnýma právama
install -o root -m 750 ./conkys_start.sh /usr/local/sbin/conkys_start.sh
install -o root -m 750 ./conkys_end.sh /usr/local/sbin/conkys_end.sh
install -o root -m 664 ./conkys@.service /etc/systemd/system/conkys@.service
install -o $uzivatel -m 664 ./99-conkys.rules /etc/udev/rules.d/99-conkys.rules
install -o $uzivatel -m 664 ./$file1 $USER_DIR/$file1
install -o $uzivatel -m 664 ./my_conf.conf $USER_DIR/my_conf.conf
# zapnutí služby
systemctl enable /etc/systemd/system/conkys@.service

else

# odinstalace
rm -f /usr/local/sbin/conkys_start.sh
rm -f /usr/local/sbin/conkys_end.sh
rm -f /etc/systemd/system/conkys@.service
rm -f /etc/udev/rules.d/99-conkys.rules
rm -f $USER_DIR/$file1
rm -f $USER_DIR/my_conf.conf

fi

# přenačtení služeb
systemctl daemon-reload
udevadm control --reload-rules
udevadm trigger

