#! /usr/bin/env bash

# ###################################################################
# ###################################################################
#      *******       Default settings **********

# Loop delay
LOOP_DELAY=10

# Time (seconds) to switch to standby
SPAT_ZA=600

# Log file. If no need logs comments line below
LOG=/var/log/conkys


################################################################################
# ------------------------------------------------------------------------------
#                     Do not change!
# ******************************************************************************

# Create log
[ $LOG ] || LOG=/dev/null

# Directory in RAM/SWAP 
OPERATIVNI_DIR=

# Config directory
USER_DIR=

konfigurak=
