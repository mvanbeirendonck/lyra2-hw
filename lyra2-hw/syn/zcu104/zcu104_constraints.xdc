# --------------------------------------------------------------------------------
# This file contains the ZCU104 evaluation logical constraints.
# --------------------------------------------------------------------------------

### TODO :: Constraint the GPIO control & data to the generated GPIO clock (50MHz)

# ---------------------------
# Clocks 
# ---------------------------
create_clock -name sysclk_125 -period 8.000 -waveform {0.000 4.000} [get_ports SYSCLK_P]


# ---------------------------
# False paths 
# ---------------------------
## URAM's 550MHz write clock is independent of read data output.
#set_false_path -from [get_pins -filter { NAME =~ "*WRCLK*" }  -of_objects [get_cells -hierarchical -filter { NAME =~ "*m_lyra2_core*" } ]] -to [get_pins -hierarchical "*d_in_w_reg[*][*]/D*"]



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
