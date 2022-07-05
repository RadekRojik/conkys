#! /usr/bin/env bash

tmp=/dev/shm/conkys
ls "$tmp" | while read -r neco
do
  [ ! -e "$tmp/$neco/temp" ] && continue
  read -r temp < <(cat "$tmp/$neco/temp")
  echo -n " $neco: $temp°C"
done
echo ""
