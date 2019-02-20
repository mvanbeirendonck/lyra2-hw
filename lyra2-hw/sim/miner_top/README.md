## Top-level simulation

Simulates the top-level Lyra2 core, including JTAG communication and FIFO interfaces.

## How to use the simulator

### Questasim

Prerequisite:- To compile and run simulation, you must compile the Xilinx simulation libraries using the 'compile_simlib' TCL command in Vivado. For more information about this command, run 'compile_simlib -help' in the Vivado Tcl Shell. 

1. setup_sim : constructs the Vivado project for simulation. Collects IP source files and exports simulation for Questasim.
2. export_sim_*/questa/tb.sh

#### See script files for detailed description on their usage.

### Vivado

Vivado simulation is currently not supported due to a known Vivado bug when using hierarchical references in mixed language scenarios, see Xilinx support AR# 69251.
