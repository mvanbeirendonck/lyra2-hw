// --------------------------------------------------------------------------------
// This file contains the evaluation board top level HDL.
// --------------------------------------------------------------------------------
`ifdef VC707
    import vc707_pkg::*; 
`endif
`ifdef ZCU104 
    import zcu104_pkg::*; 
`endif

module board_top # (
    parameter NB_OF_BLAKE_CORES    = 1, 
    parameter NB_OF_KECCAK_CORES   = 1, 
    parameter NB_OF_CUBEHASH_CORES = 1, 
    parameter NB_OF_LYRA2_CORES    = 1,
    parameter NB_OF_SKEIN_CORES    = 1, 
    parameter NB_OF_BMW_CORES      = 1,     // FIXME :: Doesn't work for more than 1 core as of now. 
    parameter GIT_HASH  = 0,
    parameter UNIX_TIME = 0
) (
    // Main reset (active-high)
    input  logic CPU_RESET, 
    
    // System clock 125.0MHz
    input  logic SYSCLK_P, 
    input  logic SYSCLK_N,  

    // Debug 
    output logic [GPIO_LEDS-1:0] GPIO_LED
); 


//=================== 
// Clocks & resets
//=================== 
logic sys_clk, core_clk, core_clk_x2, bmw_core_clk, blake_core_clk, skein_core_clk;
logic glb_reset, reset_sync_core_clk, reset_sync_core_clk_x2, reset_sync_bmw_core_clk, reset_sync_blake_core_clk, reset_sync_skein_core_clk;

clock_and_reset # (
    .BOARD_TYPE                 (BOARD_TYPE               ) 
) m_clk_rst (
    .i_main_reset               (CPU_RESET                ), 
    .i_sys_clk_p                (SYSCLK_P                 ), 
    .i_sys_clk_n                (SYSCLK_N                 ),  
    .o_sys_clk                  (sys_clk                  ),   // Free-running 
    .o_core_clk                 (core_clk                 ), 
    .o_core_clk_x2              (core_clk_x2              ),
    .o_bmw_core_clk             (bmw_core_clk             ), 
    .o_blake_core_clk           (blake_core_clk           ), 
    .o_skein_core_clk           (skein_core_clk           ), 
    .o_glb_reset                (glb_reset                ),   // Sync'ed to free-running
    .o_reset_sync_core_clk      (reset_sync_core_clk      ), 
    .o_reset_sync_core_clk_x2   (reset_sync_core_clk_x2   ),
    .o_reset_sync_bmw_core_clk  (reset_sync_bmw_core_clk  ),
    .o_reset_sync_blake_core_clk(reset_sync_blake_core_clk),
    .o_reset_sync_skein_core_clk(reset_sync_skein_core_clk)
);


//=================== 
// JTAG Master
//=================== 
logic [31:0] jtag_axi_awaddr;
logic [2 :0] jtag_axi_awprot;
logic        jtag_axi_awvalid;
logic        jtag_axi_awready;
logic [31:0] jtag_axi_wdata;
logic [3 :0] jtag_axi_wstrb;
logic        jtag_axi_wvalid;
logic        jtag_axi_wready;
logic [1 :0] jtag_axi_bresp;
logic        jtag_axi_bvalid;
logic        jtag_axi_bready;
logic [31:0] jtag_axi_araddr;
logic [2 :0] jtag_axi_arprot;
logic        jtag_axi_arvalid;
logic        jtag_axi_arready;
logic [31:0] jtag_axi_rdata;
logic [1 :0] jtag_axi_rresp;
logic        jtag_axi_rvalid;
logic        jtag_axi_rready;

`ifndef SIMULATION
    jtag_axi_master m_jtag_master (
        .aclk           (core_clk        ),     
        .aresetn        (~reset_sync_core_clk ),     
        .m_axi_awaddr   (jtag_axi_awaddr ),     
        .m_axi_awprot   (jtag_axi_awprot ),     
        .m_axi_awvalid  (jtag_axi_awvalid),     
        .m_axi_awready  (jtag_axi_awready),     
        .m_axi_wdata    (jtag_axi_wdata  ),     
        .m_axi_wstrb    (jtag_axi_wstrb  ),     
        .m_axi_wvalid   (jtag_axi_wvalid ),     
        .m_axi_wready   (jtag_axi_wready ),     
        .m_axi_bresp    (jtag_axi_bresp  ),     
        .m_axi_bvalid   (jtag_axi_bvalid ),     
        .m_axi_bready   (jtag_axi_bready ),     
        .m_axi_araddr   (jtag_axi_araddr ),     
        .m_axi_arprot   (jtag_axi_arprot ),     
        .m_axi_arvalid  (jtag_axi_arvalid),     
        .m_axi_arready  (jtag_axi_arready),     
        .m_axi_rdata    (jtag_axi_rdata  ),     
        .m_axi_rresp    (jtag_axi_rresp  ),     
        .m_axi_rvalid   (jtag_axi_rvalid ),     
        .m_axi_rready   (jtag_axi_rready )      
    );
`endif


//=================== 
// FIFO interface 
//=================== 
logic                           in_fifo_clk; 
logic                           in_fifo_reset;
logic                           in_fifo_rd_en    ;
logic [IN_FIFO_DATA_WIDTH-1:0]  in_fifo_data_out ;
logic                           in_fifo_empty    ;
logic                           in_fifo_alm_empty;
logic                           out_fifo_clk; 
logic                           out_fifo_reset; 
logic                           out_fifo_wr_en   ;
logic [OUT_FIFO_DATA_WIDTH-1:0] out_fifo_data_in ;
logic                           out_fifo_full    ;
logic                           out_fifo_alm_full;

localparam ASYNC_FIFO_INPUT  = "false";
localparam ASYNC_FIFO_OUTPUT = "false";
always_comb begin
    in_fifo_clk    = core_clk; 
    in_fifo_reset  = reset_sync_core_clk;
    out_fifo_clk   = core_clk;
    out_fifo_reset = reset_sync_core_clk; 
end 


fifo_interface # (
    .ASYNC_FIFO_INPUT       (ASYNC_FIFO_INPUT    ),
    .ASYNC_FIFO_OUTPUT      (ASYNC_FIFO_OUTPUT   ),
    .AXI_ADDR_WIDTH         (AXI_ADDR_WIDTH      ), 
    .AXI_DATA_WIDTH         (AXI_DATA_WIDTH      ),         
    .IN_FIFO_DATA_WIDTH     (IN_FIFO_DATA_WIDTH  ),         
    .IN_FIFO_DEPTH          (IN_FIFO_DEPTH       ),         
    .IN_FIFO_ALMOST_EMPTY   (IN_FIFO_ALMOST_EMPTY),         
    .OUT_FIFO_DATA_WIDTH    (OUT_FIFO_DATA_WIDTH ),         
    .OUT_FIFO_DEPTH         (OUT_FIFO_DEPTH      ),         
    .OUT_FIFO_ALMOST_FULL   (OUT_FIFO_ALMOST_FULL)           
) m_fifo_interface (
    // AXI access (JTAG)
    .i_axi_clk              (core_clk           ), 
    .i_axi_reset            (reset_sync_core_clk), 
    .i_axi_awaddr           (jtag_axi_awaddr [AXI_ADDR_WIDTH-1:0]),
    .i_axi_awvalid          (jtag_axi_awvalid),
    .o_axi_awready          (jtag_axi_awready),
    .i_axi_wdata            (jtag_axi_wdata  ),
    .i_axi_wstrb            (jtag_axi_wstrb  ),
    .i_axi_wvalid           (jtag_axi_wvalid ),
    .o_axi_wready           (jtag_axi_wready ),
    .o_axi_bresp            (jtag_axi_bresp  ),
    .o_axi_bvalid           (jtag_axi_bvalid ),
    .i_axi_bready           (jtag_axi_bready ),
    .i_axi_araddr           (jtag_axi_araddr [AXI_ADDR_WIDTH-1:0]),
    .i_axi_arvalid          (jtag_axi_arvalid),
    .o_axi_arready          (jtag_axi_arready),
    .o_axi_rdata            (jtag_axi_rdata  ),
    .o_axi_rresp            (jtag_axi_rresp  ),
    .o_axi_rvalid           (jtag_axi_rvalid ),
    .i_axi_rready           (jtag_axi_rready ),
    // Input FIFO interface
    .i_in_fifo_clk          (in_fifo_clk      ),
    .i_in_fifo_reset        (in_fifo_reset    ),
    .i_in_fifo_rd_en        (in_fifo_rd_en    ),
    .o_in_fifo_data_out     (in_fifo_data_out ),
    .o_in_fifo_empty        (in_fifo_empty    ),
    .o_in_fifo_alm_empty    (in_fifo_alm_empty),
    // Output FIFO interface 
    .i_out_fifo_clk         (out_fifo_clk     ),
    .i_out_fifo_reset       (out_fifo_reset   ),
    .i_out_fifo_wr_en       (out_fifo_wr_en   ),
    .i_out_fifo_data_in     (out_fifo_data_in ),
    .o_out_fifo_full        (out_fifo_full    ),
    .o_out_fifo_alm_full    (out_fifo_alm_full)
);


// Lyra2 miner 
lyra2_top # (
    .NB_OF_CORES  (NB_OF_LYRA2_CORES)
) m_lyra2_miner (
        .i_reset      (reset_sync_core_clk),
        .i_clk        (core_clk           ),
        .i_clk2x      (core_clk_x2        ),
        .i_d_in       (in_fifo_data_out   ),
        .i_d_in_rdy   (~in_fifo_alm_empty ),
        .o_d_in_rd    (in_fifo_rd_en      ),
        .o_d_out      (out_fifo_data_in   ),
        .o_d_out_wr   (out_fifo_wr_en     ),
        .i_d_out_rdy  (~out_fifo_alm_full ) 
);




endmodule

