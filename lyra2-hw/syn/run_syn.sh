#!/bin/bash

## Process started on:
dateTime=$(date +"%d%b%Y_%Hh%Mm%Ss")
echo "INFO :: Process started at $(date)."

## Starting PDSG script in Vivado batch mode
## Arg $1 is board type : vc707 | zcu104
## Arg $2 is pdsg type : phys_opt | no_phys_opt
## Arg $3 is number of Lyra2 cores : 1 to X
## Arg $4 is the number of Vivado threads allowed for its PDSG task
## (5th arg is the date and time)
vivado -mode batch -source lyra2rev2_pdsg.tcl -log vivado_$dateTime\.log -journal vivado_$dateTime\.jou -tclargs $1 $2 $3 $4 $dateTime 
