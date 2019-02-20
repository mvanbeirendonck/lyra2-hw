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
// This file contains the Lyra2 top level package.                        *
//                                                                        *               
//*************************************************************************

package lyra2_top_pkg; 

parameter LYRA2_PIPELINE_STAGES   = 8; 
parameter LYRA2_INPUT_DATA_WIDTH  = 256;  
parameter LYRA2_OUTPUT_DATA_WIDTH = LYRA2_INPUT_DATA_WIDTH;  
parameter COMPUTING_PERIOD        = 68*LYRA2_PIPELINE_STAGES; 

endpackage 
