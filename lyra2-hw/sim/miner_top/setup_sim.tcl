# --------------------------------------------------------------------------------
# This script creates the Vivado project for simulation.
# --------------------------------------------------------------------------------


# Step 1 : Collect source files.

set boardTarget [lindex $argv 0]
set lib_map_path [lindex $argv 1]
set NB_OF_LYRA2_CORES [lindex $argv 2]

puts "INFO :: Generating simulation files for board target $boardTarget." 
puts "INFO :: Creating project." 

if { $boardTarget == "zcu104" } {
    create_project lyra2_zcu104_sim ./lyra2_sim_zcu104 -part xczu7ev-ffvc1156-2-e
} elseif { $boardTarget == "vc707" } { 
    create_project lyra2_vc707_sim ./lyra2_sim_vc707 -part xc7vx485tffg1761-2
}
puts "INFO :: Collecting source files." 


## --> Scheduler
add_files {../../hdl/scheduler/scheduler.sv}

## --> Lyra2 core 
add_files {../../hdl/lyra2/hdl/lyra2_pkg.vhd ../../hdl/lyra2/hdl/lyra2_addw.vhd ../../hdl/lyra2/hdl/lyra2_gcomp.vhd ../../hdl/lyra2/hdl/lyra2_tdpram.vhd ../../hdl/lyra2/hdl/lyra2_ram.vhd ../../hdl/lyra2/hdl/lyra2_round.vhd ../../hdl/lyra2/hdl/lyra2_sponge.vhd ../../hdl/lyra2/hdl/lyra2.vhd ../../hdl/lyra2/hdl/lyra2_top_pkg.sv ../../hdl/lyra2/hdl/lyra2_top.sv ../../hdl/lyra2/sim/lyra2_ram.mem}

## --> Board chip top
add_files {../../hdl/fifo_interface/fifo_wrapper.sv ../../hdl/fifo_interface/fifo_interface.sv ../../hdl/clock_and_reset/clock_and_reset.sv}
if { $boardTarget == "zcu104" } {
     add_files {../../syn/zcu104/zcu104_pkg.sv ../../syn/board_top.sv}
     set_property IS_GLOBAL_INCLUDE 1 [get_files ../../syn/zcu104/zcu104_pkg.sv]
} elseif { $boardTarget == "vc707" } { 
     add_files {../../syn/vc707/vc707_pkg.sv ../../syn/board_top.sv}
     set_property IS_GLOBAL_INCLUDE 1 [get_files ../../syn/vc707/vc707_pkg.sv]
}

## --> Testbench
set_property SOURCE_SET sources_1 [get_filesets sim_1]
add_files -fileset sim_1 {./miner_tb_pkg.sv ./miner_tb.sv}
set_property IS_GLOBAL_INCLUDE 1 [get_files ./miner_tb_pkg.sv]
set_property top tb [current_fileset -simset]


## --> IP
auto_detect_xpm
add_files {../../ip/axi_master_vip/axi_master_vip.xci}
upgrade_ip [get_ips *]
generate_target {all} [get_ips *]
report_ip_status


# Step 2 : export simulation
if { $boardTarget == "zcu104" } {
     export_simulation -simulator questa -lib_map_path $lib_map_path -directory "export_sim_zcu104" -force -define {ZCU104 SIMULATION} -generic NB_OF_LYRA2_CORES=$NB_OF_LYRA2_CORES
} elseif { $boardTarget == "vc707" } { 
     export_simulation -simulator questa -lib_map_path $lib_map_path -directory "export_sim_vc707" -force -define {VC707 SIMULATION} -generic NB_OF_LYRA2_CORES=$NB_OF_LYRA2_CORES
}
