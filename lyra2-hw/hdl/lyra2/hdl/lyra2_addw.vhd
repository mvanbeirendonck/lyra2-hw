--*************************************************************************
--                                                                        *
-- Copyright (C) 2019 Michiel Van Beirendonck                             *
--                                                                        *
-- This source file may be used and distributed without                   *
-- restriction provided that this copyright statement is not              *
-- removed from the file and that any derivative work contains            *
-- the original copyright notice and the associated disclaimer.           *
--                                                                        *
-- This source file is free software; you can redistribute it             *
-- and/or modify it under the terms of the GNU Lesser General             *
-- Public License as published by the Free Software Foundation;           *
-- either version 2.1 of the License, or (at your option) any             *
-- later version.                                                         *
--                                                                        *
-- This source is distributed in the hope that it will be                 *
-- useful, but WITHOUT ANY WARRANTY; without even the implied             *
-- warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR                *
-- PURPOSE.  See the GNU Lesser General Public License for more           *
-- details.                                                               *
--                                                                        *
-- You should have received a copy of the GNU Lesser General              *
-- Public License along with this source; if not, see                     *
-- <https://www.gnu.org/licenses/>                                        *
--                                                                        *
--*************************************************************************
--                                                                        *           
-- This file contains the Lyra2 word-wise adder.                          *
--                                                                        *               
--*************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.lyra2_pkg.all;

entity lyra2_addw is
	port(
		i_a : in  sponge_b;
		i_b : in  sponge_b;
		o_c : out sponge_b
	);
end entity lyra2_addw;

architecture comb of lyra2_addw is

	signal i_a_w : uword_array(0 to 11);
	signal i_b_w : uword_array(0 to 11);
	signal o_a_w : uword_array(0 to 11);

begin

	i_a_w <= std_to_uword_array(i_a);
	i_b_w <= std_to_uword_array(i_b);
	o_c   <= uword_array_to_std(o_a_w);

	ADDW : for i in 0 to 11 generate
		ADDW : o_a_w(i) <= i_a_w(i) + i_b_w(i);
	end generate;

end architecture comb;
