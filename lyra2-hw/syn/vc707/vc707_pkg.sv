// --------------------------------------------------------------------------------
// This file contains the VC707 board's package.
// --------------------------------------------------------------------------------

package vc707_pkg; 

    parameter BOARD_TYPE           = "VC707"; 
    parameter GPIO_LEDS            = 8; 
    parameter AXI_ADDR_WIDTH       = 8; 
    parameter AXI_DATA_WIDTH       = 32;         
    parameter PIPELINE_DEPTH       = 8;     // Lyra2 core internal pipeline depth 
    parameter IN_FIFO_DATA_WIDTH   = 256;   // Input hash is 256 bits
    parameter IN_FIFO_DEPTH        = 128;         
    parameter IN_FIFO_ALMOST_EMPTY = PIPELINE_DEPTH;         
    parameter OUT_FIFO_DATA_WIDTH  = 256;         
    parameter OUT_FIFO_DEPTH       = 128;         
    parameter OUT_FIFO_ALMOST_FULL = OUT_FIFO_DEPTH-PIPELINE_DEPTH;

endpackage 
