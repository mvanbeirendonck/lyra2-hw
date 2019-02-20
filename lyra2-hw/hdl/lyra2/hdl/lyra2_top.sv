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
// This file contains the Lyra2 top level HDL.                            *
//                                                                        *               
//*************************************************************************

import lyra2_top_pkg::*; 

module lyra2_top # (
    parameter NB_OF_CORES = 1
) (
    input  logic                         i_reset    ,
    input  logic                         i_clk      ,
    input  logic                         i_clk2x    ,
    input  logic [LYRA2_INPUT_DATA_WIDTH-1:0]  i_d_in     ,
    input  logic                         i_d_in_rdy ,  // Input FIFO not almost empty (LYRA2_PIPELINE_STAGES)
    output logic                         o_d_in_rd  ,
    output logic [LYRA2_OUTPUT_DATA_WIDTH-1:0] o_d_out    ,
    output logic                         o_d_out_wr ,
    input  logic                         i_d_out_rdy   // Output FIFO not almost full (depth - NB_OF_CORES * LYRA2_PIPELINE_STAGES)
); 

generate 
    if ( NB_OF_CORES == 1 ) begin : gen_single_lyra2
        
        // Back-pressure
        logic data_ready; 
        always_comb data_ready = i_d_in_rdy & i_d_out_rdy;  

        // Single Lyra2 core w/o scheduler
        lyra2 m_lyra2_core (
            .i_reset      (i_reset      ),
            .i_clk        (i_clk        ),
            .i_clk2x      (i_clk2x      ),
            .i_din        (i_d_in       ),
            .i_din_rdy    (data_ready   ),
            .o_din_rd     (o_d_in_rd    ),
            .o_dout       (o_d_out      ),
            .o_dout_wr    (o_d_out_wr   ) 
        );

    end else begin : gen_multi_lyra2

        // Scheduler
        logic [NB_OF_CORES-1:0] lyra2_d_in_rdy   ;
        logic [NB_OF_CORES-1:0] lyra2_d_in_rd_en ;
        logic [NB_OF_CORES-1:0][LYRA2_OUTPUT_DATA_WIDTH-1:0] lyra2_d_out;
        logic [NB_OF_CORES-1:0] lyra2_d_out_wr_en;

        scheduler # (
            .NB_OF_CORES          (NB_OF_CORES            ),
            .OUTPUT_DATA_WIDTH    (LYRA2_OUTPUT_DATA_WIDTH),
            .COMPUTING_PERIOD     (COMPUTING_PERIOD       ),
            .CORE_PIPELINE_STAGES (LYRA2_PIPELINE_STAGES  ) 
        ) m_scheduler (
            .i_reset              (i_reset          ),
            .i_clk                (i_clk            ),
            // Scheduler input interface
            .i_d_in_rdy           (i_d_in_rdy       ),  
            .o_d_in_rd            (o_d_in_rd        ),
            // Cores interface
            .o_core_d_in_rdy      (lyra2_d_in_rdy   ),
            .i_core_d_in_rd_en    (lyra2_d_in_rd_en ),
            .i_core_d_out         (lyra2_d_out      ),
            .i_core_d_out_wr_en   (lyra2_d_out_wr_en), 
            // Scheduler output interface
            .o_d_out              (o_d_out          ),
            .o_d_out_wr           (o_d_out_wr       ),
            .i_d_out_rdy          (i_d_out_rdy      )   
        ); 

        // Lyra2 cores
        lyra2 m_lyra2_core [NB_OF_CORES]  (
            .i_reset      ({NB_OF_CORES{i_reset}}),
            .i_clk        ({NB_OF_CORES{i_clk  }}),
            .i_clk2x      ({NB_OF_CORES{i_clk2x}}),
            .i_din        ({NB_OF_CORES{i_d_in }}),
            .i_din_rdy    (lyra2_d_in_rdy        ),
            .o_din_rd     (lyra2_d_in_rd_en      ),
            .o_dout       (lyra2_d_out           ),
            .o_dout_wr    (lyra2_d_out_wr_en     ) 
        );

    end
endgenerate 

endmodule 
