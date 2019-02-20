## Core-level simulation

Simulates the Lyra2 core against a set of test vectors. The number of Lyra2 cores instantiated is configurable through script inputs; multiple cores are handled through the HDL scheduler.

## How to use the simulator

1. gen_lyra2_ram_init if NPPL was changed in lyra2_pkg.vhd

### Modelsim

Prerequisite:- To compile and run simulation, you must compile the Xilinx simulation libraries using the 'compile_simlib' TCL command in Vivado. For more information about this command, run 'compile_simlib -help' in the Vivado Tcl Shell. Once the libraries have been compiled successfully, the modelsim.ini file must be placed in this folder.

2. run_sim 

3. clean_folder

### Vivado

2. run_xsim 

3. clean_folder

#### See script files for detailed description on their usage.




