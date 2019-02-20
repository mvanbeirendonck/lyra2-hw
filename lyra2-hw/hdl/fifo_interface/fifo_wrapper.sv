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
// This file contains a fifo wrapper for the XPM ones.                    *
//                                                                        *               
//*************************************************************************

module fifo_wrapper # (
    parameter TYPE                  = "sync",   // "async" or "sync" 
    parameter MEMORY_TYPE           = "bram",   // "bram", "uram" or "lutram" (distributed)     
    parameter DEPTH                 = 2048  ,   // fifo depth
    parameter DATA_WIDTH            = 32    ,   // input and output data width 
    parameter PROG_FULL_THRESH      = 10    ,   // programmable full threshold  
    parameter READ_MODE             = "std" ,   // "std" or "fwft" (first-word fall through)  
    parameter READ_LATENCY          = 1     ,   // can be 0 for FWFT read mode  
    parameter PROG_EMPTY_THRESH     = 10        // programmable empty threshold  
) (
    // Common module ports
    input  logic                     i_reset     ,
    // Write Domain ports
    input  logic                     i_wr_clk    ,
    input  logic                     i_wr_en     ,
    input  logic [DATA_WIDTH-1:0]    i_data_in   ,
    output logic                     o_full      ,
    output logic                     o_prog_full ,
    output logic [$clog2(DEPTH):0]   o_wr_level  ,
    output logic                     o_overflow  ,
    // Read Domain ports
    input  logic                     i_rd_clk    ,  // Not used in "sync" mode
    input  logic                     i_rd_en     ,
    output logic [DATA_WIDTH-1:0]    o_data_out  ,
    output logic                     o_empty     ,
    output logic                     o_prog_empty,
    output logic [$clog2(DEPTH):0]   o_rd_level  ,
    output logic                     o_underflow
); 

generate 
    if (TYPE == "async") begin
        xpm_fifo_async # (
            // Common module parameters
            .FIFO_MEMORY_TYPE     (MEMORY_TYPE      ),
            .ECC_MODE             ("NO_ECC"         ),
            .RELATED_CLOCKS       (0                ),
            .FIFO_WRITE_DEPTH     (DEPTH            ),
            .WRITE_DATA_WIDTH     (DATA_WIDTH       ),
            .WR_DATA_COUNT_WIDTH  ($clog2(DEPTH)+1  ),
            .PROG_FULL_THRESH     (PROG_FULL_THRESH ),
            .FULL_RESET_VALUE     (0                ),
            .USE_ADV_FEATURES     ("0707"           ),
            .READ_MODE            (READ_MODE        ),
            .FIFO_READ_LATENCY    (READ_LATENCY     ),
            .READ_DATA_WIDTH      (DATA_WIDTH       ),
            .RD_DATA_COUNT_WIDTH  ($clog2(DEPTH)+1  ),
            .PROG_EMPTY_THRESH    (PROG_EMPTY_THRESH),
            .DOUT_RESET_VALUE     ("0"              ),
            .CDC_SYNC_STAGES      (2                ),
            .WAKEUP_TIME          (0                )
        ) xpm_fifo_async_inst (
            // Common module ports
            .sleep                (1'b0             ),
            .rst                  (i_reset          ),
            // Write Domain ports
            .wr_clk               (i_wr_clk         ),
            .wr_en                (i_wr_en          ),
            .din                  (i_data_in        ),
            .full                 (o_full           ),
            .prog_full            (o_prog_full      ),
            .wr_data_count        (o_wr_level       ),
            .overflow             (o_overflow       ),
            .wr_rst_busy          (),
            .almost_full          (),
            .wr_ack               (),
            // Read Domain ports  
            .rd_clk               (i_rd_clk         ),
            .rd_en                (i_rd_en          ),
            .dout                 (o_data_out       ),
            .empty                (o_empty          ),
            .prog_empty           (o_prog_empty     ),
            .rd_data_count        (o_rd_level       ),
            .underflow            (o_underflow      ),
            .rd_rst_busy          (),
            .almost_empty         (),
            .data_valid           (),
            // ECC Related ports  
            .injectsbiterr        (),
            .injectdbiterr        (),
            .sbiterr              (),
            .dbiterr              ()
        );
    end else if ( TYPE == "sync" ) begin
        xpm_fifo_sync # (
            // Common module parameters
            .FIFO_MEMORY_TYPE     (MEMORY_TYPE      ),
            .ECC_MODE             ("NO_ECC"         ),
            .FIFO_WRITE_DEPTH     (DEPTH            ),
            .WRITE_DATA_WIDTH     (DATA_WIDTH       ),
            .WR_DATA_COUNT_WIDTH  ($clog2(DEPTH)+1  ),
            .PROG_FULL_THRESH     (PROG_FULL_THRESH ),
            .FULL_RESET_VALUE     (0                ),
            .USE_ADV_FEATURES     ("0707"           ),
            .READ_MODE            (READ_MODE        ),
            .FIFO_READ_LATENCY    (READ_LATENCY     ),
            .READ_DATA_WIDTH      (DATA_WIDTH       ),
            .RD_DATA_COUNT_WIDTH  ($clog2(DEPTH)+1  ),
            .PROG_EMPTY_THRESH    (PROG_EMPTY_THRESH),
            .DOUT_RESET_VALUE     ("0"              ),
            .WAKEUP_TIME          (0                )
        ) xpm_fifo_sync_inst (
            // Common module ports
            .sleep                (1'b0             ),
            .rst                  (i_reset          ),
            // Write Domain ports
            .wr_clk               (i_wr_clk         ),
            .wr_en                (i_wr_en          ),
            .din                  (i_data_in        ),
            .full                 (o_full           ),
            .prog_full            (o_prog_full      ),
            .wr_data_count        (o_wr_level       ),
            .overflow             (o_overflow       ),
            .wr_rst_busy          (),
            .almost_full          (),
            .wr_ack               (),
            // Read Domain ports  
            .rd_en                (i_rd_en          ),
            .dout                 (o_data_out       ),
            .empty                (o_empty          ),
            .prog_empty           (o_prog_empty     ),
            .rd_data_count        (o_rd_level       ),
            .underflow            (o_underflow      ),
            .rd_rst_busy          (),
            .almost_empty         (),
            .data_valid           (),
            // ECC Related ports  
            .injectsbiterr        (),
            .injectdbiterr        (),
            .sbiterr              (),
            .dbiterr              ()
        );
    end 
endgenerate 

// Simulation assertions
always @ ( posedge i_wr_en ) begin 
    assert ( o_overflow == 1'b0 ) 
        else $fatal(0, "[FATAL (%0t) %m: Detected FIFO overflow!", $time);
end 
always @ ( negedge i_rd_en ) begin
    assert ( o_underflow == 1'b0 ) 
        else $fatal(0, "[FATAL (%0t) %m: Detected FIFO underflow!", $time);
end 

endmodule
