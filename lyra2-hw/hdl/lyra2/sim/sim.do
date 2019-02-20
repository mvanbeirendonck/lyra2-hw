# --------------------------------------------------------------------------------
# This file contains the ASIC tester compilation and simulation script.
# --------------------------------------------------------------------------------

# Get input arguments
set NB_OF_CORES $1
set SIM_CMD ""
if { $2 == "log_all" } {
    set SIM_CMD "set StdArithNoWarnings 1; set NumericStdNoWarnings 1; log * -r; add wave -r /*; run -all; exit"
} else {
    set SIM_CMD "set StdArithNoWarnings 1; set NumericStdNoWarnings 1; log /*; add wave /*; run -all; exit"
}

# Creating compilation workspace
vlib work
vmap work work

# Compilation

## --> Scheduler
vlog -sv -work work ../../scheduler/scheduler.sv

## --> Lyra2 core 
vcom -work work -check_synthesis ../hdl/lyra2_pkg.vhd
vcom -work work -check_synthesis ../hdl/lyra2_addw.vhd
vcom -work work -check_synthesis ../hdl/lyra2_gcomp.vhd
vcom -work work -check_synthesis ../hdl/lyra2_tdpram.vhd
vcom -work work -check_synthesis ../hdl/lyra2_ram.vhd
vcom -work work -check_synthesis ../hdl/lyra2_round.vhd
vcom -work work -check_synthesis ../hdl/lyra2_sponge.vhd
vcom -work work -check_synthesis ../hdl/lyra2.vhd
vlog -sv -work work ../hdl/lyra2_top_pkg.sv
vlog -sv -work work ../hdl/lyra2_top.sv

## --> Testbench
vcom -2008 -work work -check_synthesis ./lyra2_tb.vhd


# Elaboration and simulation 
vsim -c -voptargs="+acc" -t 1ps \
-L xpm \
-G NB_OF_CORES=$NB_OF_CORES \
-logfile lyra2_sim.log \
-wlf lyra2_sim.wlf \
-do $SIM_CMD \
work.lyra2_tb 
