#! /usr/bin/env bash

out="|"

cti () {
while read -r neco
do
  read -r temp < <(cat $tmp/$neco/$tmp1 2> /dev/null || continue) || continue
  out="$out$neco|conkys $neco|${temp:0:2}|C||"
done <<<$vystup
}


tmp=/sys/block
tmp1="device/device/hwmon/*/temp1_input"
vystup=`ls "$tmp" || 2> /dev/null`
cti

tmp=/dev/shm/conkys
tmp1=temp
# vystup=`ls "$tmp"`
cti

[ "$out" ] && echo $out

