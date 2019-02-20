#!/bin/sh

## Removing old compiled work libraries
rm -vfr ./work/

## Compilation + simulation. 
## Arg $1 is NB_OF_CORES : 1 to N; 
## Arg $2 is wave logging level : log_all or no_log.  
vsim -l lyra2_compile.log -c -do "do sim.do $1 $2"
