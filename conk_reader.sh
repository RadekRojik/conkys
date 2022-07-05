#! /usr/bin/env bash

tmp=/dev/shm/conkys
while read -r neco
do
  [ ! -e "$tmp/$neco/temp" ] && continue
  read -r temp < <(cat "$tmp/$neco/temp")
  out="$out$neco: $temp°C "
done <<<$(ls "$tmp")
[ "$out" ] && echo $out
