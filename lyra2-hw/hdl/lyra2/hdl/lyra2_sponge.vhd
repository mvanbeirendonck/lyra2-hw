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
-- This file contains the Lyra2 sponge.                                   *
--                                                                        *               
--*************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.lyra2_pkg.all;

entity lyra2_sponge is
	port(
		clk     : in  std_logic;
		i_clr   : in  std_logic;
		i_din   : in  sponge_b;
		o_dout : out sponge_b
	);
end entity lyra2_sponge;

architecture rtl of lyra2_sponge is

	signal state_reg, latency_reg  : sponge_s; -- sponge state register
	signal round_in, round_out : sponge_s; -- round in/out


begin

	P_REG : process(clk) is
	begin
		if rising_edge(clk) then
			
			state_reg <= latency_reg;
			
			if i_clr = '1' then
				latency_reg                  <= (others => '0');
				latency_reg(1023 downto 512) <= BLAKE2B_IV;
			else
				latency_reg <= round_out;
			end if;
		end if;
	end process P_REG;
	
	P_ROUND_IN : process(state_reg, i_din) is
	begin	
		round_in <= state_reg;
		round_in(SPONGE_BB-1 downto 0) <= state_reg(SPONGE_BB-1 downto 0) xor i_din;	
	end process P_ROUND_IN;

	
	o_dout <= round_out(SPONGE_BB-1 downto 0);
	
	ROUND : entity work.lyra2_round
		port map(
			clk   => clk,
			i_din  => round_in,
			o_dout  => round_out);

end architecture rtl;

