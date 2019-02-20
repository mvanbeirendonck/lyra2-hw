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
// This file contains the clocking logic and reset scheme.                *
//                                                                        *               
//*************************************************************************

module clock_and_reset # ( 
    parameter BOARD_TYPE = "ZCU104" // Can be "VC707" or "ZCU104" 
) (
    // Main reset (active-high)
    input  logic i_main_reset, 
    
    // Fixed-frequency crystal
    input  logic i_sys_clk_p, 
    input  logic i_sys_clk_n,  

    // Generated clocks
    output logic o_sys_clk, 
    output logic o_core_clk, 
    output logic o_core_clk_x2,
    output logic o_bmw_core_clk, 
    output logic o_blake_core_clk, 
    output logic o_skein_core_clk, 

    // Generated resets
    output logic o_glb_reset, 
    output logic o_reset_sync_core_clk, 
    output logic o_reset_sync_core_clk_x2,
    output logic o_reset_sync_bmw_core_clk,
    output logic o_reset_sync_blake_core_clk,
    output logic o_reset_sync_skein_core_clk
);

//=================== 
// Clocking
//===================                                      ZCU104   VC707
localparam CLKFBOUT_MULT_F  = ( BOARD_TYPE == "ZCU104" ) ? 8.000  : 3.500   ;   
localparam CLKIN1_PERIOD    = ( BOARD_TYPE == "ZCU104" ) ? 8.000  : 5.000   ;   // 125MHz | 200MHz
localparam CLKOUT0_DIVIDE_F = ( BOARD_TYPE == "ZCU104" ) ? 4.000  : 4.000   ;   // 250MHz | 175MHz
localparam CLKOUT1_DIVIDE   = ( BOARD_TYPE == "ZCU104" ) ? 2      : 2       ;   // 500MHz | 350MHz
localparam CLKOUT2_DIVIDE   = ( BOARD_TYPE == "ZCU104" ) ? 60     : 2       ;   // 16.6MHz| ???MHz
localparam CLKOUT3_DIVIDE   = ( BOARD_TYPE == "ZCU104" ) ? 18     : 2       ;   // 55.5MHz| ???MHz
localparam CLKOUT4_DIVIDE   = ( BOARD_TYPE == "ZCU104" ) ? 12     : 2       ;   // 83.3MHz| ???MHz
localparam DIVCLK_DIVIDE    = ( BOARD_TYPE == "ZCU104" ) ? 1      : 1       ;   

logic glb_reset; 
logic sys_clk; 
logic mmcm_clk_fb_pb, mmcm_clk_fb; 
logic mmcm_clk, mmcm_clk_x2, mmcm_clk_bmw, mmcm_clk_blake, mmcm_clk_skein;
logic mmcm_locked;
logic core_clk; 

// Input differential clock buffer
IBUFDS # (
    .DQS_BIAS   ("FALSE") 
) m_ibufds_sys_clk (
    .I          (i_sys_clk_p), 
    .IB         (i_sys_clk_n),
    .O          (o_sys_clk  )   
);

// Mixed-mode clock manager (MMCM) :
// --> Clock 0 : Core Clock @ 175/250MHz
// --> Clock 1 : Core Clock x 2 @ 350/500MHz
// --> Clock 2 : BMW core clock @ 16.6MHz
// --> Clock 3 : Blake core clock @ 55.5MHz
// --> CLock 4 : Skein core clock @ 83.3MHz
MMCME2_BASE # (
    .BANDWIDTH          ("OPTIMIZED"     ),
    .CLKFBOUT_MULT_F    (CLKFBOUT_MULT_F ),
    .CLKFBOUT_PHASE     (0.0             ),
    .CLKIN1_PERIOD      (CLKIN1_PERIOD   ),
    .CLKOUT0_DIVIDE_F   (CLKOUT0_DIVIDE_F),
    .CLKOUT1_DIVIDE     (CLKOUT1_DIVIDE  ),
    .CLKOUT2_DIVIDE     (CLKOUT2_DIVIDE  ),
    .CLKOUT3_DIVIDE     (CLKOUT3_DIVIDE  ),
    .CLKOUT4_DIVIDE     (CLKOUT4_DIVIDE  ),
    .CLKOUT0_DUTY_CYCLE (0.5             ),
    .CLKOUT1_DUTY_CYCLE (0.5             ),
    .CLKOUT2_DUTY_CYCLE (0.5             ),
    .CLKOUT3_DUTY_CYCLE (0.5             ),
    .CLKOUT4_DUTY_CYCLE (0.5             ),
    .CLKOUT0_PHASE      (0.0             ),
    .CLKOUT1_PHASE      (0.0             ),
    .CLKOUT2_PHASE      (0.0             ),
    .CLKOUT3_PHASE      (0.0             ),
    .CLKOUT4_PHASE      (0.0             ),
    .CLKOUT4_CASCADE    ("FALSE"         ),
    .DIVCLK_DIVIDE      (DIVCLK_DIVIDE   ),
    .REF_JITTER1        (0.0             ),
    .STARTUP_WAIT       ("FALSE"         ) 
) m_mmcm_clocks (
    // Control
    .PWRDWN             (1'b0          ),       
    .RST                (1'b0          ),  
    .CLKIN1             (o_sys_clk     ),     
    .CLKFBOUT           (mmcm_clk_fb_pb),   
    .CLKFBIN            (mmcm_clk_fb   ),    
    .LOCKED             (mmcm_locked   ),     
    // Clock outputs
    .CLKOUT0            (mmcm_clk      ),    
    .CLKOUT1            (mmcm_clk_x2   ),    
    .CLKOUT2            (mmcm_clk_bmw  ),           
    .CLKOUT3            (mmcm_clk_blake),           
    .CLKOUT4            (mmcm_clk_skein),           
    // Unused 
    .CLKFBOUTB          (), 
    .CLKOUT0B           (),           
    .CLKOUT1B           (),           
    .CLKOUT2B           (),           
    .CLKOUT3B           (),           
    .CLKOUT5            (),           
    .CLKOUT6            ()           
);

// Feedback & output buffering
// TODO :: HERE
BUFG mmcm_clk_buf_inst [6]
(
    .I ({mmcm_clk_fb_pb, 
         mmcm_clk      , 
         mmcm_clk_x2   , 
         mmcm_clk_bmw  , 
         mmcm_clk_blake, 
         mmcm_clk_skein}),
    .O ({mmcm_clk_fb     , 
         o_core_clk      , 
         o_core_clk_x2   , 
         o_bmw_core_clk  , 
         o_blake_core_clk, 
         o_skein_core_clk})
);


//===================
// Reset
//=================== 

// Asserted and deasserted synchronously to destination clock
xpm_cdc_sync_rst # (
    .DEST_SYNC_FF   (4), 
    .INIT           (0), 
    .SIM_ASSERT_CHK (1) 
) xpm_cdc_sync_rst_inst [6] (
    .src_rst        ({i_main_reset, {5{o_glb_reset}}}),
    .dest_clk       ({o_sys_clk       , 
                      o_core_clk      , 
                      o_core_clk_x2   , 
                      o_bmw_core_clk  , 
                      o_blake_core_clk, 
                      o_skein_core_clk}),
    .dest_rst       ({o_glb_reset                , 
                      o_reset_sync_core_clk      , 
                      o_reset_sync_core_clk_x2   , 
                      o_reset_sync_bmw_core_clk  , 
                      o_reset_sync_blake_core_clk, 
                      o_reset_sync_skein_core_clk})
);


endmodule
