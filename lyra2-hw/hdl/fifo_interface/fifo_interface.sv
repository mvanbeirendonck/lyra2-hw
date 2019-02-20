//*************************************************************************
//                                                                        *
// Copyright (C) 2019 Louis-Charles Trudeau                               *
//                                                                        *
// This source file may be used and distributed without                   *
// restriction provided that this copyright statement is not              *
// removed from the file and that any derivative work contains            *
// the original copyright notice and the associated disclaimer.           *
//                                                                        *
// This source file is free software; you can redistribute it             *
// and/or modify it under the terms of the GNU Lesser General             *
// Public License as published by the Free Software Foundation;           *
// either version 2.1 of the License, or (at your option) any             *
// later version.                                                         *
//                                                                        *
// This source is distributed in the hope that it will be                 *
// useful, but WITHOUT ANY WARRANTY; without even the implied             *
// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR                *
// PURPOSE.  See the GNU Lesser General Public License for more           *
// details.                                                               *
//                                                                        *
// You should have received a copy of the GNU Lesser General              *
// Public License along with this source; if not, see             	  *
// <https://www.gnu.org/licenses/>                              	  *
//                                                                        *
//*************************************************************************
//                                                                        *           
// This file contains the interface between the outside world (JTAG) and  *
// the core.                                                              *
//                                                                        *               
//*************************************************************************
module fifo_interface # (
    parameter ASYNC_FIFO_INPUT     = "false",
    parameter ASYNC_FIFO_OUTPUT    = "false",
    parameter AXI_ADDR_WIDTH       = 8, 
    parameter AXI_DATA_WIDTH       = 32,         
    parameter IN_FIFO_DATA_WIDTH   = 256,         
    parameter IN_FIFO_DEPTH        = 128,         
    parameter IN_FIFO_ALMOST_EMPTY = 5,         
    parameter OUT_FIFO_DATA_WIDTH  = 256,         
    parameter OUT_FIFO_DEPTH       = 128,         
    parameter OUT_FIFO_ALMOST_FULL = OUT_FIFO_DEPTH-5           
) (
    // AXI access (JTAG)
    input  logic                      i_axi_clk    , 
    input  logic                      i_axi_reset  , 
    input  logic [AXI_ADDR_WIDTH-1:0] i_axi_awaddr ,
    input  logic                      i_axi_awvalid,
    output logic                      o_axi_awready,
    input  logic [AXI_DATA_WIDTH-1:0] i_axi_wdata  ,
    input  logic [3:0]                i_axi_wstrb  ,
    input  logic                      i_axi_wvalid ,
    output logic                      o_axi_wready ,
    output logic [1:0]                o_axi_bresp  ,
    output logic                      o_axi_bvalid ,
    input  logic                      i_axi_bready ,
    input  logic [AXI_ADDR_WIDTH-1:0] i_axi_araddr ,
    input  logic                      i_axi_arvalid,
    output logic                      o_axi_arready,
    output logic [AXI_DATA_WIDTH-1:0] o_axi_rdata  ,
    output logic [1:0]                o_axi_rresp  ,
    output logic                      o_axi_rvalid ,
    input  logic                      i_axi_rready ,
    // Input FIFO interface
    input  logic                          i_in_fifo_clk      ,   
    input  logic                          i_in_fifo_reset    ,  
    input  logic                          i_in_fifo_rd_en    ,
    output logic [IN_FIFO_DATA_WIDTH-1:0] o_in_fifo_data_out ,
    output logic                          o_in_fifo_empty    ,
    output logic                          o_in_fifo_alm_empty,
    // Output FIFO interface 
    input  logic                           i_out_fifo_clk     ,   
    input  logic                           i_out_fifo_reset   ,  
    input  logic                           i_out_fifo_wr_en   ,
    input  logic [OUT_FIFO_DATA_WIDTH-1:0] i_out_fifo_data_in ,
    output logic                           o_out_fifo_full    ,
    output logic                           o_out_fifo_alm_full
);

localparam IN_FIFO_REG_SPACE = IN_FIFO_DATA_WIDTH/AXI_DATA_WIDTH; 
localparam OUT_FIFO_REG_SPACE = OUT_FIFO_DATA_WIDTH/AXI_DATA_WIDTH; 

// Register interface from JTAG AXI to FIFOs.
// This interface only works with the AXI4-lite protocol.

// FIFO register interface    
typedef struct packed {
    bit [IN_FIFO_REG_SPACE-1:0][AXI_DATA_WIDTH-1:0] in_word;
    bit [OUT_FIFO_REG_SPACE-1:0][AXI_DATA_WIDTH-1:0] out_word;
} t_fifo_if;
t_fifo_if fifo_if; 

logic axi_awready = 1'b0; 
logic axi_wready  = 1'b0; 
logic axi_bvalid  = 1'b0; 
logic in_fifo_write_req = 1'b0; 
logic in_fifo_wr_en = 1'b0;
logic [IN_FIFO_DATA_WIDTH-1:0] in_fifo_data_in;
logic [$clog2(IN_FIFO_DEPTH):0] in_fifo_level;
logic in_fifo_full, in_fifo_prog_full;
logic in_fifo_overflow, in_fifo_underflow;

// Write operation
always_ff @ (posedge i_axi_clk) begin
    if ( i_axi_reset == 1'b1 ) begin
        // Reset write channel
        axi_awready <= 1'b0; 
        axi_wready  <= 1'b0; 
        axi_bvalid  <= 1'b0; 
        // FIFO related
        in_fifo_write_req <= 1'b0; 
        in_fifo_wr_en <= 1'b0;
    end else begin
        axi_awready <= 1'b0; 
        axi_wready  <= 1'b0; 
        in_fifo_wr_en <= 1'b0;

        // AXI write access
        if ( i_axi_awvalid == 1'b1 && i_axi_wvalid == 1'b1  ) begin
            if ( i_axi_awaddr < IN_FIFO_REG_SPACE ) begin
                    fifo_if.in_word[i_axi_awaddr] <= i_axi_wdata; 
                    // Initiate FIFO write transaction
                    if ( i_axi_awaddr == IN_FIFO_REG_SPACE-1 ) begin
                        in_fifo_write_req <= 1'b1;
                    end 
                    // Make sure no outstanding FIFO write transaction
                    if ( in_fifo_write_req == 1'b0 ) begin 
                        axi_wready <= 1'b1; 
                    end 
                end 
            axi_awready <= 1'b1;
        end
        
        // FIFO write transaction
        if ( in_fifo_write_req == 1'b1 && in_fifo_full == 1'b0 ) begin
            in_fifo_data_in   <= {<<32{fifo_if.in_word}}; //FIXME : 32 should be AXI_DATA_WIDTH, but errors in Modelsim
            in_fifo_wr_en     <= 1'b1;
            in_fifo_write_req <= 1'b0; 
        end 
        
        // Write transaction complete
        axi_bvalid <= axi_wready & i_axi_bready & i_axi_wvalid;   
    end 
end 

// Input FIFO 
localparam INPUT_FIFO_TYPE = (ASYNC_FIFO_INPUT == "true") ? "async" : "sync"; 
fifo_wrapper # (
    .TYPE               (INPUT_FIFO_TYPE     ),
    .READ_MODE          ("fwft"              ),
    .DEPTH              (IN_FIFO_DEPTH       ),
    .DATA_WIDTH         (IN_FIFO_DATA_WIDTH  ),
    .PROG_EMPTY_THRESH  (IN_FIFO_ALMOST_EMPTY)   
) m_input_fifo (
    // Common module ports
    .i_reset            (i_axi_reset        ),
    // Write Domain ports
    .i_wr_clk           (i_axi_clk          ),
    .i_wr_en            (in_fifo_wr_en      ),
    .i_data_in          (in_fifo_data_in    ),
    .o_full             (in_fifo_full       ),
    .o_prog_full        (/*nc*/),
    .o_wr_level         (/*nc*/),
    .o_overflow         (in_fifo_overflow   ),
    // Read Domain ports
    .i_rd_clk           (i_in_fifo_clk      ),
    .i_rd_en            (i_in_fifo_rd_en    ),
    .o_data_out         (o_in_fifo_data_out ),
    .o_empty            (o_in_fifo_empty    ),
    .o_prog_empty       (o_in_fifo_alm_empty),
    .o_rd_level         (in_fifo_level      ),  // Same as write level in sync mode
    .o_underflow        (in_fifo_underflow  )
); 


// Read operation
typedef enum logic [1:0] {IDLE, FIFO_REQ, FIFO_RD, REG_RD} t_rd_fsm_state;
t_rd_fsm_state rd_fsm_state; 
logic axi_arready = 1'b0;
logic axi_rvalid  = 1'b0;
logic out_fifo_rd_en = 1'b0, out_fifo_rd_en_d1;
logic [OUT_FIFO_DATA_WIDTH-1:0] out_fifo_data_out;
logic [$clog2(OUT_FIFO_DEPTH):0] out_fifo_level;
logic out_fifo_empty, out_fifo_prog_empty;
logic out_fifo_overflow, out_fifo_underflow;
logic [$clog2(OUT_FIFO_REG_SPACE)-1:0] read_reg_addr;  

always_ff @ (posedge i_axi_clk) begin
    if ( i_axi_reset == 1'b1 ) begin
        // Reset read channel
        axi_arready <= 1'b0;
        axi_rvalid  <= 1'b0;
        o_axi_rdata   <= 32'b0;
        // FIFO related 
        rd_fsm_state <= IDLE; 
        out_fifo_rd_en <= 1'b0; 

    end else begin
        // Init
        axi_arready <= 1'b0;
        out_fifo_rd_en <= 1'b0;
        axi_rvalid <= 1'b0;
        
        case ( rd_fsm_state ) 
            IDLE : begin
                if ( i_axi_arvalid == 1'b1 ) begin
                    // Ack read access
                    axi_arready <= 1'b1; 
                    if ( i_axi_araddr == IN_FIFO_REG_SPACE ) begin
                        rd_fsm_state <= FIFO_REQ; 
                        read_reg_addr <= 0;         
                    end else if ( i_axi_araddr > IN_FIFO_REG_SPACE && i_axi_araddr < (IN_FIFO_REG_SPACE+OUT_FIFO_REG_SPACE) ) begin
                        rd_fsm_state <= REG_RD;
                        read_reg_addr <= i_axi_araddr - IN_FIFO_REG_SPACE; 
                    end else begin
                        o_axi_rdata <= 32'hDEADBEEF;
                        rd_fsm_state <= REG_RD; 
                    end 
                end 
            end 
            
            FIFO_REQ : begin
                if ( out_fifo_empty == 1'b0 ) begin
                    out_fifo_rd_en <= 1'b1; 
                    rd_fsm_state <= FIFO_RD; 
                end 
            end 

            FIFO_RD : begin
                // 1 clock cycle latency
                if ( out_fifo_rd_en_d1 == 1'b1 ) begin
                    fifo_if.out_word <= {<<32{out_fifo_data_out}}; //FIXME : 32 should be AXI_DATA_WIDTH, but errors in Modelsim
                    rd_fsm_state <= REG_RD; 
                end  
            end 

            REG_RD : begin
                o_axi_rdata <= fifo_if.out_word[read_reg_addr];
                axi_rvalid <= 1'b1;
                rd_fsm_state <= IDLE;         
            end 
        endcase

        // FIFO read latency
        out_fifo_rd_en_d1 <= out_fifo_rd_en; 
    end 
end 


// Output FIFO 
localparam OUTPUT_FIFO_TYPE = (ASYNC_FIFO_OUTPUT == "true") ? "async" : "sync"; 
fifo_wrapper # (
    .TYPE               (OUTPUT_FIFO_TYPE    ),
    .DEPTH              (OUT_FIFO_DEPTH      ),
    .DATA_WIDTH         (OUT_FIFO_DATA_WIDTH ),
    .PROG_FULL_THRESH   (OUT_FIFO_ALMOST_FULL)   
) m_output_fifo (
    // Common module ports
    .i_reset            (i_out_fifo_reset   ),
    // Write Domain ports
    .i_wr_clk           (i_out_fifo_clk     ),
    .i_wr_en            (i_out_fifo_wr_en   ),
    .i_data_in          (i_out_fifo_data_in ),
    .o_full             (o_out_fifo_full    ),
    .o_prog_full        (o_out_fifo_alm_full),
    .o_wr_level         (out_fifo_level     ),
    .o_overflow         (out_fifo_overflow  ),
    // Read Domain ports
    .i_rd_clk           (i_axi_clk          ), 
    .i_rd_en            (out_fifo_rd_en     ),
    .o_data_out         (out_fifo_data_out  ),
    .o_empty            (out_fifo_empty     ),
    .o_prog_empty       (out_fifo_prog_empty),
    .o_rd_level         (/*nc*/),               // Same as write level in sync mode
    .o_underflow        (out_fifo_underflow )
); 


// Output assignments
always_comb begin
    o_axi_bresp   <= 2'b0;
    o_axi_rresp   <= 2'b0;
    o_axi_awready <= axi_awready; 
    o_axi_wready  <= axi_wready ; 
    o_axi_bvalid  <= axi_bvalid ; 
    o_axi_arready <= axi_arready;
    o_axi_rvalid  <= axi_rvalid ;
end 

endmodule 
