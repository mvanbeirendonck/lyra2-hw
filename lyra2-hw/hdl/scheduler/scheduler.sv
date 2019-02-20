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
// This file contains the algorithm core scheduler HDL.                   *
//                                                                        *               
//*************************************************************************

module scheduler # (
    parameter NB_OF_CORES          = 5,
    parameter OUTPUT_DATA_WIDTH    = 256,  
    parameter COMPUTING_PERIOD     = 68, 
    parameter CORE_PIPELINE_STAGES = 1 

) (
    input  logic                         i_reset    ,
    input  logic                         i_clk      ,
    
    // Scheduler input interface
    input  logic                         i_d_in_rdy ,  // Input FIFO not almost empty 
    output logic                         o_d_in_rd  ,
    
    // Cores interface
    output logic [NB_OF_CORES-1:0]       o_core_d_in_rdy   ,
    input  logic [NB_OF_CORES-1:0]       i_core_d_in_rd_en ,
    input  logic [NB_OF_CORES-1:0][OUTPUT_DATA_WIDTH-1:0] i_core_d_out,
    input  logic [NB_OF_CORES-1:0]       i_core_d_out_wr_en,
    
    // Scheduler output interface
    output logic [OUTPUT_DATA_WIDTH-1:0] o_d_out    ,
    output logic                         o_d_out_wr ,
    input  logic                         i_d_out_rdy   // Output FIFO not almost full
); 

//-----------------------------------------------------------------------------
// TODO :: Be able to shift register data input as soon as we have 1 hash ready
//-----------------------------------------------------------------------------

typedef struct packed {
    logic compute_ena; 
    logic [$clog2(COMPUTING_PERIOD):0] compute_cycle; 
} t_status; 
t_status [NB_OF_CORES-1:0] core_status; 
logic compute_rdy;
typedef enum logic[1:0] {IDLE, WAIT, CHARGE_DATA} t_fsm_state;
t_fsm_state fsm_state; 

// Back-pressure and data input throttling 
always_comb begin
    compute_rdy = i_d_in_rdy & i_d_out_rdy; 
    for ( int i = 0; i < NB_OF_CORES; i++ ) begin
        if ( i_core_d_in_rd_en[i] == 1'b1 ) begin
            o_d_in_rd = 1'b1;
            break;  
        end else begin 
            o_d_in_rd = 1'b0; 
        end 
    end
end  

//---------------------------------
// Input data round-robin scheduler 
//---------------------------------
logic [$clog2(NB_OF_CORES)-1:0] core_cur_ptr, core_next_ptr; 

// Scheduler pointers 
always_comb begin
    if ( core_cur_ptr < NB_OF_CORES-1 ) begin
        core_next_ptr = core_cur_ptr + 1;
    end else begin
        core_next_ptr = 0; 
    end 
end 

// Main FSM
always_ff @ ( posedge i_clk ) begin
    if ( i_reset == 1'b1 ) begin
        fsm_state     <= IDLE; 
        core_cur_ptr  <= 0; 
        for ( int i = 0; i < NB_OF_CORES; i++ ) begin
            core_status[i].compute_ena   <= '0; 
            core_status[i].compute_cycle <= '0; 
            o_core_d_in_rdy[i]           <= 1'b0; 
        end 
    end else begin

        // Scheduler FSM
        case ( fsm_state )
            IDLE : begin
                if ( compute_rdy == 1'b1 && core_status[core_cur_ptr].compute_ena == 1'b0 ) begin        
                    o_core_d_in_rdy[core_cur_ptr] <= 1'b1; 
                    fsm_state <= WAIT; 
                end
            end  
           
            WAIT : begin
                // Wait for FIFO read latency
                if ( i_core_d_in_rd_en[core_cur_ptr] == 1'b1 ) begin
                    core_status[core_cur_ptr].compute_ena <= 1'b1; 
                    fsm_state <= CHARGE_DATA; 
                end 
            end 

            CHARGE_DATA : begin
                // Wait until we finish loading 5 hashes
                if ( core_status[core_cur_ptr].compute_cycle >= CORE_PIPELINE_STAGES-1 ) begin
                    o_core_d_in_rdy[core_cur_ptr] <= 1'b0;
                    core_cur_ptr <= core_next_ptr;
                    // Check if we can skip the IDLE state directly
                    if ( compute_rdy == 1'b1 && core_status[core_next_ptr].compute_ena == 1'b0 ) begin        
                        o_core_d_in_rdy[core_next_ptr] <= 1'b1; 
                        fsm_state <= WAIT; 
                    end else begin 
                        fsm_state <= IDLE; 
                    end 
                end 
            end 
        endcase

        // Compute cycle adders
        for ( int i = 0; i < NB_OF_CORES; i++ ) begin
            if ( core_status[i].compute_ena == 1'b1 ) begin 
                if ( core_status[i].compute_cycle < COMPUTING_PERIOD ) begin
                    core_status[i].compute_cycle <= core_status[i].compute_cycle + 1'b1; 
                end else begin
                    core_status[i].compute_cycle <= '0;
                    core_status[i].compute_ena   <= 1'b0; 
                end
            end 
        end  
    end 
end 

//-------------------------------
// Data output (fire and forget)
//-------------------------------
always_ff @ ( posedge i_clk ) begin
    for ( int i = 0; i < NB_OF_CORES; i++ ) begin
        if ( i_core_d_out_wr_en[i] == 1'b1 ) begin
            o_d_out_wr <= 1'b1; 
            o_d_out    <= i_core_d_out[i]; 
            break; 
        end else begin
            o_d_out_wr <= 1'b0; 
        end  
    end 
end 

endmodule 

