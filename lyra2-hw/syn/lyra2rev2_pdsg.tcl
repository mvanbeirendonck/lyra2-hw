# --------------------------------------------------------------------------------
# This script runs all the physical design task required to create a bitstream
# --------------------------------------------------------------------------------

# STEP 1 : Initialize the project.
set boardTarget [lindex $argv 0]
set minerType "lyra2"
set pdsgType [lindex $argv 1]
set nbLyra2Cores [lindex $argv 2]
set pdsgThreads [lindex $argv 3]
set systemTime [lindex $argv 4]

if { $boardTarget == "zcu104" } {
    set chipset "xczu7ev-ffvc1156-2-e"
    set xilinxTech "Zynq UltraScale+"
} elseif { $boardTarget == "vc707" } { 
    set chipset "xc7vx485tffg1761-2"
    set xilinxTech "Virtex 7"
}

if { $pdsgThreads >= 1 && $pdsgThreads <= 8 } {
    puts "INFO :: Setting Vivado maximum number of threads to $pdsgThreads for the PDSG."
    set_param general.maxThreads $pdsgThreads
}
set projectName [lindex [split [pwd] "/"] [expr [llength [split [pwd] "/"]]-2]]
puts "INFO :: Starting PDSG for project [string toupper $projectName]."
puts "INFO :: Targeting $xilinxTech [string toupper $chipset] on [string toupper $boardTarget] evaluation board."

set projectPath "./$boardTarget/run_$systemTime"
file mkdir $projectPath
puts "INFO :: Created synthesis folder at $projectPath."
set_part $chipset

# STEP 2 : setup design sources and constraints
if { $minerType == "lyra2" } {
    puts "INFO :: Compiling Lyra2 miner sources."
    puts "INFO :: Miner configuration : $nbLyra2Cores Lyra2 cores."
    ## VHDL files 
    read_vhdl [ glob ../hdl/lyra2/hdl/lyra2_pkg.vhd ]
    read_vhdl [ glob ../hdl/lyra2/hdl/lyra2_addw.vhd ]
    read_vhdl [ glob ../hdl/lyra2/hdl/lyra2_gcomp.vhd ]
    read_vhdl [ glob ../hdl/lyra2/hdl/lyra2_tdpram.vhd ]
    read_vhdl [ glob ../hdl/lyra2/hdl/lyra2_ram.vhd ]
    read_vhdl [ glob ../hdl/lyra2/hdl/lyra2_round.vhd ]
    read_vhdl [ glob ../hdl/lyra2/hdl/lyra2_sponge.vhd ]
    read_vhdl [ glob ../hdl/lyra2/hdl/lyra2.vhd ]
    ## Verilog/SystemVerilog files
    read_verilog -sv [ glob ../hdl/lyra2/hdl/lyra2_top_pkg.sv ]
    read_verilog -sv [ glob ../hdl/lyra2/hdl/lyra2_top.sv ]
}

## Common HDL
read_verilog -sv [ glob ./$boardTarget/$boardTarget\_pkg.sv ]
read_verilog -sv [ glob ../hdl/scheduler/scheduler.sv ]
read_verilog -sv [ glob ../hdl/fifo_interface/fifo_wrapper.sv ]
read_verilog -sv [ glob ../hdl/fifo_interface/fifo_interface.sv ]
read_verilog -sv [ glob ../hdl/clock_and_reset/clock_and_reset.sv ]
read_verilog -sv [ glob ./board_top.sv ]

## IP cores
auto_detect_xpm -verbose
read_ip [ glob ../ip/jtag_axi_master/jtag_axi_master.xci ]

upgrade_ip [get_ips *]
generate_target {all} [get_ips *]
report_ip_status

# Constraints files
read_xdc ./$boardTarget/$boardTarget\_physical.xdc
read_xdc ./$boardTarget/$boardTarget\_constraints.xdc


# STEP 3 : run synthesis, write design checkpoint, report timing, and utilization estimates
puts "INFO \[SYNTHESIS\] :: Running synthesis ([clock format [clock seconds] -format %Hh%Mm%Ss.]), flatten hierarchy is set to rebuilt."
synth_design -top board_top -verilog_define [string toupper $boardTarget] -verilog_define [string toupper $minerType] -generic NB_OF_LYRA2_CORES=$nbLyra2Cores -part $chipset -flatten_hierarchy rebuilt -verbose
write_checkpoint -force $projectPath/post_synth.dcp
report_timing_summary -file $projectPath/post_synth_timing_summary.rpt
report_utilization -hierarchical -file $projectPath/post_synth_util.rpt

## Step 3.1 : create debug ILA core
#source ./create_debug_ila.tcl

# STEP 4 : run logic optimization, placement and physical logic optimization, write design checkpoint, report utilization and timing estimates
puts "INFO \[OPTIMIZATION\] :: Optimizing synthesized logic ([clock format [clock seconds] -format %Hh%Mm%Ss.])."
opt_design -directive Explore -verbose
power_opt_design -verbose
report_power_opt -file  $projectPath/power_opt.rpt
puts "INFO \[PLACEMENT\] :: Running placer using Explore directive ([clock format [clock seconds] -format %Hh%Mm%Ss.])."
place_design -directive Explore -verbose
report_clock_utilization -file $projectPath/clock_util.rpt

## Optionally run optimization if there are timing violations after placement
if { $pdsgType == "phys_opt" && [ get_property SLACK [ get_timing_paths -max_paths 1 -nworst 1 -setup ] ] < 0 } {
    puts "INFO \[PLACEMENT\] :: Found setup timing violations. Running physical optimization once ([clock format [clock seconds] -format %Hh%Mm%Ss.])."
    phys_opt_design -directive AggressiveExplore
    phys_opt_design -directive AlternateReplication
    phys_opt_design -directive AggressiveFanoutOpt
}

write_checkpoint -force $projectPath/post_place.dcp
report_utilization -hierarchical -file $projectPath/post_place_util.rpt
report_timing_summary -file $projectPath/post_place_timing_summary.rpt


# STEP 5 : route design, write the post-route design checkpoint, report the routing status, timing, power, DRC, and finally save the Verilog netlist.
puts "INFO \[ROUTING\] :: Running router using Explore directive ([clock format [clock seconds] -format %Hh%Mm%Ss.])."
route_design -directive Explore -verbose

## Optionally run optimization if there are timing violations after routing 
if { $pdsgType == "phys_opt" && [ get_property SLACK [ get_timing_paths -max_paths 1 -nworst 1 -setup ] ] < 0 } {
    puts "INFO \[ROUTING\] :: Found setup timing violations. Running physical optimization once ([clock format [clock seconds] -format %Hh%Mm%Ss.])."
    phys_opt_design -directive AggressiveExplore
    phys_opt_design -directive AlternateReplication
    phys_opt_design -directive AggressiveFanoutOpt
}

write_checkpoint -force $projectPath/post_route.dcp
report_route_status -file $projectPath/post_route_status.rpt
report_timing_summary -file $projectPath/post_route_timing_summary.rpt
report_power -file $projectPath/post_route_power.rpt
report_drc -file $projectPath/post_implementation_drc.rpt
write_verilog -force $projectPath/$projectName\_netlist.v -mode timesim -sdf_anno true


# STEP 6 : generate a bitstream
set final_wns [ get_property SLACK [ get_timing_paths -max_paths 1 -nworst 1 -setup ] ]
set final_whs [ get_property SLACK [ get_timing_paths -max_paths 1 -nworst 1 -hold ] ]
if { $final_wns >= 0 && $final_whs >= 0 } {
    puts "INFO :: Generating the final bitstream."
    write_bitstream -force $projectPath/$projectName\_[clock format [clock seconds] -format {%d%b%Y_%Hh%Mm%Ss}].bit
    puts "INFO :: Generating the ILA debug probes."
    write_debug_probes -force $projectPath/$projectName\_debug_ila_probes.ltx
} else {
    puts "ERROR !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    puts "ERROR :: Found setup timing violations; did not generate bitstream!"
    puts "ERROR !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
} 

puts "INFO :: Process stopped on [clock format [clock seconds] -format {%d %B %Y at %Hh%Mm%Ss.}]" 


# Outro : Copy vivado log to current folder
file rename -force $projectPath/../../vivado_$systemTime.log $projectPath/pdsg_report.log
file rename -force $projectPath/../../vivado_$systemTime.jou $projectPath/pdsg_report.jou


