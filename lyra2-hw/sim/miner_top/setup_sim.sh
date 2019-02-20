#!/bin/sh

## Setup the Vivado project for top-level simulation
## --> arg $1 is the board target : vc707 | zcu104
## --> arg $2 is the path to the compiled Xilinx simulation libraries
## --> arg $3 is the number of lyra2 cores
vivado -mode batch -source setup_sim.tcl -log vivado_$dateTime\.log -journal vivado_$dateTime\.jou -tclargs $1 $2 $3
