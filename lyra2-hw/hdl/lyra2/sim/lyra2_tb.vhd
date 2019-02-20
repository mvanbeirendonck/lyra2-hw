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
-- Public License along with this source; if not, see             	  *
-- <https://www.gnu.org/licenses/>                                        *
--                                                                        *
--*************************************************************************
--                                                                        *           
-- This file contains the Lyra2 testbench.                                *
--                                                                        *               
--*************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std; 
use std.textio.all;
use std.env.all; 

use work.lyra2_pkg.all;

entity lyra2_tb is
generic(NB_OF_CORES : integer := 1);
end;

architecture bench of lyra2_tb is

    constant CLK_PER : time := 4 ns;

    signal reset      : std_logic; 
    signal clk, clk2x : std_logic := '1';
    signal done       : boolean;

    signal d_in       : std_logic_vector(HWIDTH - 1 downto 0);
    signal d_in_rdy   : std_logic;
    signal d_in_rd    : std_logic;
    signal d_out      : std_logic_vector(HWIDTH - 1 downto 0);
    signal d_out_wr   : std_logic;
    signal d_out_rdy  : std_logic;

begin

    -- Clocks
    clk   <= not clk after CLK_PER / 2 when not done;
    clk2x <= not clk2x after CLK_PER / 4 when not done;

    -- DUT
    DUV : entity work.lyra2_top
        generic map (
            NB_OF_CORES => NB_OF_CORES 
        )
        port map (
            i_reset     => reset, 
            i_clk       => clk,
            i_clk2x     => clk2x,
            i_d_in      => d_in,
            i_d_in_rdy  => d_in_rdy,
            o_d_in_rd   => d_in_rd,
            o_d_out     => d_out,
            o_d_out_wr  => d_out_wr,
            i_d_out_rdy => d_out_rdy
        );

    -- Data in process
    P_D_IN : process
        file lyra2_in      : text open read_mode is "./vectors/lyra2_in.txt";
        variable line_in   : line;
        variable data_read : std_logic_vector(HWIDTH - 1 downto 0);
    begin
        reset <= '1'; 
        wait for 24 ns; 
        reset <= '0'; 
        while not endfile(lyra2_in) loop
            readline(lyra2_in, line_in);
            hread(line_in, data_read);
            d_in       <= data_read;
            d_in_rdy   <= '1';
            wait until rising_edge(clk) and d_in_rd = '1';
        end loop; 
        wait; 
    end process P_D_IN;

    -- Data out process
    P_D_OUT : process
        file lyra2_out     : text open read_mode is "./vectors/lyra2_ref_out.txt";
        variable line_in   : line;
        variable data_read : std_logic_vector(HWIDTH - 1 downto 0);
        variable i         : integer := 1;
    begin
        d_out_rdy <= '0'; 
        wait for 32 ns; 
        d_out_rdy <= '1'; 
        while not endfile(lyra2_out) loop 
            readline(lyra2_out, line_in);
            hread(line_in, data_read);
            wait until rising_edge(clk) and d_out_wr = '1';
            assert data_read = d_out report "Assertion violation. Reference = " & to_hstring(data_read) & ", data =  " &  to_hstring(d_out) severity failure;
            report "(" & integer'image(i) & ") Passed test.";
            i := i + 1;
        end loop;
        -- Simulation is done!
        stop(2); 
    end process P_D_OUT;

end architecture bench;
