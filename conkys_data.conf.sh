#! /usr/bin/env bash

# ###################################################################
# ###################################################################
#      *******       Defaultní nastavení   **********
# konfigurační soubor `conkys`
# zde jsou uloženy defaultní předvolby

# rychlost smyčky
LOOP_DELAY=10

# za jak dlouho se má disk přepnout do standby
SPAT_ZA=600

# Soubor logu. Pokud se nechce logovat, je třeba jen zakomentovat následující řádek
LOG=/var/log/conkys


################################################################################
# ------------------------------------------------------------------------------
#                     odtud nic neměnit!
# ******************************************************************************

# Kontrola a nastavení LOGu. Pokud je logování nežádoucí bude se "zahazovat"
[ $LOG ] || LOG=/dev/null

# Adresář v RAM/SWAP paměti. OS ví lépe kam to umístit. A vytvářet extra RAM
# disk se mi nechce.
OPERATIVNI_DIR=

# konfigurační adresář
USER_DIR=

konfigurak=$USER_DIR/my_conf.conf