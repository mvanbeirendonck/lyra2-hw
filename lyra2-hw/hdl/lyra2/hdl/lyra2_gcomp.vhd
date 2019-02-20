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
-- This file contains the Lyra2 G-function.                               *
--                                                                        *               
--*************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.lyra2_pkg.all;

entity lyra2_gcomp is
	port(
		clk : in  std_logic;
		i_a : in  uword;
		i_b : in  uword;
		i_c : in  uword;
		i_d : in  uword;
		o_a : out uword;
		o_b : out uword;
		o_c : out uword;
		o_d : out uword
		--o_row : out row_cnt
	);
end entity lyra2_gcomp;

architecture ppl2 of lyra2_gcomp is

	type uword_array is array (0 to 3) of uword;

	signal a : uword_array;
	signal b : uword_array;
	signal c : uword_array;
	signal d : uword_array;

	signal add0, add1, add2, add3 : uword;
begin

	-- pipeline
	process(clk) is 
	begin
		if rising_edge(clk) then

			a(1) <= a(0);
			b(1) <= b(0);
			c(1) <= add1;
			d(1) <= d(0);
			
			o_a <= a(3);
			o_b <= b(3);
			o_c <= c(3);
			o_d <= d(3);

		end if;
	end process;

	add0 <= i_a + i_b;
	add1 <= c(0) + ((d(0) xor add0) ror 32);
	add2 <= a(1) + b(2);
	add3 <= c(2) + d(3);

	a(0) <= add0;
	b(0) <= i_b;
	c(0) <= i_c;
	d(0) <= i_d;

	a(2) <= add2;
	b(2) <= (b(1) xor c(1)) ror 24;
	c(2) <= c(1);
	d(2) <= ((d(1) xor a(1)) ror 32);

	a(3) <= a(2);
	b(3) <= (b(2) xor add3) ror 63;
	c(3) <= add3;
	d(3) <= (d(2) xor add2) ror 16;

end architecture ppl2;



