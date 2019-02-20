// --------------------------------------------------------------------------------
// This file contains the miner core top testbench.
// --------------------------------------------------------------------------------

`timescale 1ps/1ps

import tb_pkg::*; 
import axi_vip_pkg::*;
import axi_master_vip_pkg::*;

module tb (); 

// Parameters that control the number of cores in the full-chain.
parameter NB_OF_BLAKE_CORES     = 2; 
parameter NB_OF_KECCAK_CORES    = 2; 
parameter NB_OF_CUBEHASH_CORES  = 11; 
parameter NB_OF_LYRA2_CORES     = 4; 
parameter NB_OF_SKEIN_CORES     = 2; 
parameter NB_OF_BMW_CORES       = 1;    // FIXME :: Doesn't work for more than 1 core as of now. 

logic reset; 
logic clock_p = 1'b0, clock_n; 

`ifdef VC707 
    // Local oscillator is 200MHz 
    localparam CLK_PERIOD = 5000;
`endif
`ifdef ZCU104
    // Local oscillator is 125MHz 
    localparam CLK_PERIOD = 8000;
`endif
    
//---------------------------------------------------------------------//
// DUT : Miner chip top
//---------------------------------------------------------------------//

// Board target 
board_top # (
    .NB_OF_BLAKE_CORES    (NB_OF_BLAKE_CORES   ), 
    .NB_OF_KECCAK_CORES   (NB_OF_KECCAK_CORES  ), 
    .NB_OF_CUBEHASH_CORES (NB_OF_CUBEHASH_CORES), 
    .NB_OF_LYRA2_CORES    (NB_OF_LYRA2_CORES   ),
    .NB_OF_SKEIN_CORES    (NB_OF_SKEIN_CORES   ), 
    .NB_OF_BMW_CORES      (NB_OF_BMW_CORES     ), 
    .GIT_HASH             (0),
    .UNIX_TIME            (0)
) m_board_top (
    // Main reset (active-high)
    .CPU_RESET  (reset), 
    // System clock (VC707 : 200.0MHz, ZCU104 : 125MHz)
    .SYSCLK_P   (clock_p), 
    .SYSCLK_N   (clock_n),  
    // Debug 
    .GPIO_LED   ()
); 


//---------------------------------------------------------------------//
// JTAG AXI Master VIP
//---------------------------------------------------------------------//
axi_master_vip jtag_axi_master_vip (
    .aclk               (m_board_top.core_clk        ),  
    .aresetn            (~m_board_top.reset_sync_core_clk),  
    .m_axi_awaddr       (m_board_top.jtag_axi_awaddr ),  
    .m_axi_awprot       (m_board_top.jtag_axi_awprot ),  
    .m_axi_awvalid      (m_board_top.jtag_axi_awvalid),  
    .m_axi_awready      (m_board_top.jtag_axi_awready),  
    .m_axi_wdata        (m_board_top.jtag_axi_wdata  ),  
    .m_axi_wstrb        (m_board_top.jtag_axi_wstrb  ),  
    .m_axi_wvalid       (m_board_top.jtag_axi_wvalid ),  
    .m_axi_wready       (m_board_top.jtag_axi_wready ),  
    .m_axi_bvalid       (m_board_top.jtag_axi_bvalid ),  
    .m_axi_bready       (m_board_top.jtag_axi_bready ),  
    .m_axi_araddr       (m_board_top.jtag_axi_araddr ),  
    .m_axi_arprot       (m_board_top.jtag_axi_arprot ),  
    .m_axi_arvalid      (m_board_top.jtag_axi_arvalid),  
    .m_axi_arready      (m_board_top.jtag_axi_arready),  
    .m_axi_rdata        (m_board_top.jtag_axi_rdata  ),  
    .m_axi_rresp        (m_board_top.jtag_axi_rresp  ),  
    .m_axi_rvalid       (m_board_top.jtag_axi_rvalid ),  
    .m_axi_rready       (m_board_top.jtag_axi_rready )   
);                       

//---------------------------------------------------------------------//
// Simulation
//---------------------------------------------------------------------//
logic [DECODE_WIDTH-1:0] write_data; 
integer data_width = DECODE_WIDTH; 
logic [DECODE_WIDTH-1:0] read_data; 
logic receiving_hash = 1'b0; 
xil_axi_uint mst_agent_verbosity = XIL_AXI_VERBOSITY_FULL;
bit [axi_master_vip_VIP_DATA_WIDTH-1:0]  reg_rd_data;
axi_master_vip_mst_t mst_agent;
xil_axi_resp_t wr_txn_resp, rd_txn_resp;     
string err_msg = "", err_stack = ""; 
xil_axi_uint wr_txn_depth = 16, rd_txn_depth = 16; 
semaphore axi_bus = new(1); 

// Generate clocks 
always begin
    # (CLK_PERIOD/2) clock_p = ~clock_p;
    clock_n = ~clock_p;  
end 


// Main routine
initial begin
    $display ("INFO :: STARTING SIMULATION!"); 
    
    // Initialize everything
    reset = 1'b1; 
    
    // Create the agent
    mst_agent = new("MasterVIP",jtag_axi_master_vip.inst.IF);
    mst_agent.set_agent_tag("Master VIP");
    mst_agent.set_verbosity(mst_agent_verbosity);
    mst_agent.start_master();

    // Wait 32 system clock cycles : global reset
    repeat (256) @ (negedge m_board_top.core_clk);
    
    // Deassert reset
    reset = 1'b0;

    // Wait 32 system clock cycles : global reset
    repeat (256) @ (negedge m_board_top.core_clk);

    fork 
        // Sending data to the miner through JTAG axi_write access
        begin
            foreach ( expected_data.input_block[block_idx] ) begin
                axi_bus.get(1); 
                write_data = {<<{expected_data.input_block[block_idx]}}; 
                $display("INFO :: Write data # %0d : 0x%0h", block_idx, write_data); 
                for ( int addr = 0; addr < IN_FIFO_REG_SPACE; addr++ ) begin
                    $display("Write data to address 0x%0h : 0x%0h", addr, write_data[addr*AXI_DATA_WIDTH+:AXI_DATA_WIDTH]); 
                    axi_write(addr, write_data[addr*AXI_DATA_WIDTH+:AXI_DATA_WIDTH], 0); 
                end
                axi_bus.put(1);
                @ ( posedge m_board_top.core_clk); 
            end 
        end 
        // Receiving data from the miner through JTAG axi_read access
        begin
            foreach ( expected_data.output_block[block_idx] ) begin
                wait ( m_board_top.m_fifo_interface.out_fifo_empty == 1'b0 ); 
                //wait ( m_board_top.m_fifo_interface.out_fifo_level > 50 ); 
                axi_bus.get(1); 
                receiving_hash = 1'b1; 
                for ( int addr = 0; addr < OUT_FIFO_REG_SPACE; addr++ ) begin
                    axi_read(addr+IN_FIFO_REG_SPACE, read_data[addr*AXI_DATA_WIDTH+:AXI_DATA_WIDTH], 0); 
                    $display("Read data 0x%0h at address : 0x%0h", read_data[addr*AXI_DATA_WIDTH+:AXI_DATA_WIDTH], addr+IN_FIFO_REG_SPACE); 
                end
                $display("INFO :: Read data # %0d : 0x%0h", block_idx, read_data); 
                axi_bus.put(1); 
                receiving_hash = 1'b0; 
                @ ( posedge m_board_top.core_clk);
                if (block_idx == 100) 
                    $stop; 
            end 
        end 
        // Checkers TODO :: Add checkers for JTAG input and output
        //check_expected("Miner Input ", data_width  , m_board_top.in_fifo_data_out, m_board_top.in_fifo_rd_en , expected_data.input_block , m_board_top.core_clk);       
        check_expected_hash("Miner Output", m_board_top.out_fifo_data_in, m_board_top.out_fifo_wr_en, expected_data.output_block, m_board_top.core_clk);  
    join 

    // Stop simulation 
    $display ("INFO :: SIMULATION ENDED!"); 
    $stop; 
end


// File I/O
t_expected_data expected_data; 

initial begin
    // Reading input and output expected hashing values  
    fork 
        read_vectors(expected_data.input_block , DECODE_WIDTH, vectors_path.cubehash0); 
        read_vectors(expected_data.output_block, DECODE_WIDTH, vectors_path.lyra2    ); 
    join 
end 


//---------------------------------------------------------------------//
// Tasks and functions 
//---------------------------------------------------------------------//

task axi_write; 
    input xil_axi_ulong address; 
    input bit [AXI_DATA_WIDTH-1:0] write_data; 
    input int log_fd;

    xil_axi_resp_t wr_txn_resp; 
    mst_agent.AXI4LITE_WRITE_BURST(address, 3'b0, write_data, wr_txn_resp);

    if (log_fd != 0) 
        $fwrite(log_fd, "\naxi_write 0x%8H 0x%8H", address, write_data); 
endtask

task axi_read; 
    input xil_axi_ulong address; 
    output bit [AXI_DATA_WIDTH-1:0] read_data; 
    input int log_fd;

    xil_axi_resp_t rd_txn_resp; 
    mst_agent.AXI4LITE_READ_BURST(address, 3'b0, read_data, rd_txn_resp);

    //$fwrite(log_fd, "\naxi_read 0x%8H 0x%8H", address, read_data); 
endtask

// Miner statistics 
initial begin
    // Average hashrate (running-mean)
    get_average_hashrate(m_board_top.core_clk, receiving_hash, 20); 
end 
endmodule 
