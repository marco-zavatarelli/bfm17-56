#!/bin/sh
for i in a b c d
do
  ln -sf bfm_EXP1${i}.nml bfm.nml
#  ./bfm_standalone_UNIBO.x
  ./bfm_standalone.x
done