# --------------------------------------------------------------------------------
# This file contains the Vivado compilation and simulation script.
# --------------------------------------------------------------------------------

## Compilation + simulation. 
## Arg $1 is NB_OF_CORES : 1 to N; 

## --> Lyra2 core 
xvhdl ../hdl/lyra2_pkg.vhd
xvhdl ../hdl/lyra2_addw.vhd
xvhdl ../hdl/lyra2_gcomp.vhd
xvhdl ../hdl/lyra2_tdpram.vhd
xvhdl ../hdl/lyra2_ram.vhd
xvhdl ../hdl/lyra2_round.vhd
xvhdl ../hdl/lyra2_sponge.vhd
xvhdl ../hdl/lyra2.vhd

xvlog -sv ../hdl/lyra2_top_pkg.sv
xvlog -sv ../hdl/lyra2_top.sv

## --> Scheduler
xvlog -sv ../../scheduler/scheduler.sv

## --> Testbench
xvhdl -2008 ./lyra2_tb.vhd


# Elaboration 
xelab -L xpm -s lyra2_sim --relax -debug typical -generic_top "NB_OF_CORES=$1" work.lyra2_tb  

# Simulation
xsim lyra2_sim -R -wdb lyra2_sim.wdb


