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
-- This file contains the Lyra2 round function.                           *
--                                                                        *               
--*************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.lyra2_pkg.all;

entity lyra2_round is
	port(
		clk    : in  std_logic;
		i_din  : in  sponge_s;
		o_dout : out sponge_s
	);
end entity lyra2_round;

architecture pipe of lyra2_round is

	signal din_w  : uword_array(0 to 15);
	signal dmid_w : uword_array(0 to 15);
	signal dout_w : uword_array(0 to 15);

begin

	din_w  <= std_to_uword_array(i_din) when rising_edge(clk);
	o_dout <= uword_array_to_std(dout_w) when rising_edge(clk);

	G0 : entity work.lyra2_gcomp
		port map(clk   => clk,
		         i_a   => din_w(0),
		         i_b   => din_w(4),
		         i_c   => din_w(8),
		         i_d   => din_w(12),
		         o_a   => dmid_w(0),
		         o_b   => dmid_w(4),
		         o_c   => dmid_w(8),
		         o_d   => dmid_w(12));

	G1 : entity work.lyra2_gcomp
		port map(clk   => clk,
		         i_a   => din_w(1),
		         i_b   => din_w(5),
		         i_c   => din_w(9),
		         i_d   => din_w(13),
		         o_a   => dmid_w(1),
		         o_b   => dmid_w(5),
		         o_c   => dmid_w(9),
		         o_d   => dmid_w(13));

	G2 : entity work.lyra2_gcomp
		port map(clk   => clk,
		         i_a   => din_w(2),
		         i_b   => din_w(6),
		         i_c   => din_w(10),
		         i_d   => din_w(14),
		         o_a   => dmid_w(2),
		         o_b   => dmid_w(6),
		         o_c   => dmid_w(10),
		         o_d   => dmid_w(14));

	G3 : entity work.lyra2_gcomp
		port map(clk   => clk,
		         i_a   => din_w(3),
		         i_b   => din_w(7),
		         i_c   => din_w(11),
		         i_d   => din_w(15),
		         o_a   => dmid_w(3),
		         o_b   => dmid_w(7),
		         o_c   => dmid_w(11),
		         o_d   => dmid_w(15));

	G4 : entity work.lyra2_gcomp
		port map(clk   => clk,
		         i_a   => dmid_w(0),
		         i_b   => dmid_w(5),
		         i_c   => dmid_w(10),
		         i_d   => dmid_w(15),
		         o_a   => dout_w(0),
		         o_b   => dout_w(5),
		         o_c   => dout_w(10),
		         o_d   => dout_w(15));

	G5 : entity work.lyra2_gcomp
		port map(clk   => clk,
		         i_a   => dmid_w(1),
		         i_b   => dmid_w(6),
		         i_c   => dmid_w(11),
		         i_d   => dmid_w(12),
		         o_a   => dout_w(1),
		         o_b   => dout_w(6),
		         o_c   => dout_w(11),
		         o_d   => dout_w(12));

	G6 : entity work.lyra2_gcomp
		port map(clk   => clk,
		         i_a   => dmid_w(2),
		         i_b   => dmid_w(7),
		         i_c   => dmid_w(8),
		         i_d   => dmid_w(13),
		         o_a   => dout_w(2),
		         o_b   => dout_w(7),
		         o_c   => dout_w(8),
		         o_d   => dout_w(13));

	G7 : entity work.lyra2_gcomp
		port map(clk   => clk,
		         i_a   => dmid_w(3),
		         i_b   => dmid_w(4),
		         i_c   => dmid_w(9),
		         i_d   => dmid_w(14),
		         o_a   => dout_w(3),
		         o_b   => dout_w(4),
		         o_c   => dout_w(9),
		         o_d   => dout_w(14));

end architecture pipe;

