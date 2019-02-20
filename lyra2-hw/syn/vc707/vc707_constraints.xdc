# --------------------------------------------------------------------------------
# This file contains the VC707 evaluation logical constraints.
# --------------------------------------------------------------------------------

### TODO :: Constraint the GPIO control & data to the generated GPIO clock (50MHz)

# ---------------------------
# Clocks 
# ---------------------------
create_clock -name sysclk_200 -period 5.000 -waveform {0.000 2.500} [get_ports SYSCLK_P]


# ---------------------------
# False paths 
# ---------------------------



# ---------------------------
# Multi-cycle paths 
# ---------------------------
set_multicycle_path 2 -setup -start -from [get_clocks *mmcm_clk_x2] -to [get_clocks *mmcm_clk]
set_multicycle_path 1 -hold -from [get_clocks *mmcm_clk_x2] -to [get_clocks *mmcm_clk]

set_multicycle_path 2 -setup -from [get_clocks *mmcm_clk] -to [get_clocks *mmcm_clk_x2]
set_multicycle_path 1 -hold -end -from [get_clocks *mmcm_clk] -to [get_clocks *mmcm_clk_x2]



# ---------------------------
# Input and output FFs in IOB
# ---------------------------
#set_property IOB true [all_inputs]
#set_property IOB true [all_outputs]
