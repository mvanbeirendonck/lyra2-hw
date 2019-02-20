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
-- This file contains the Lyra2 (4R/2W) RAM using replication and multi-  *
-- pumping.                                                               *
--                                                                        *               
--*************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.lyra2_pkg.all;

entity lyra2_ram is
    port(
        i_reset         : in  std_logic; 
        i_clk           : in  std_logic;
        i_clk2x         : in  std_logic;
        i_wraddress_a : in  ram_address;
        i_wraddress_b : in  ram_address;
        i_rdaddress_a : in  ram_address;
        i_rdaddress_b : in  ram_address;
        i_rdaddress_c : in  ram_address;
        i_rdaddress_d : in  ram_address;
        i_data_a      : in  sponge_b;
        i_data_b      : in  sponge_b;
        i_wren_a      : in  std_logic;
        i_wren_b      : in  std_logic;
        o_q_a         : out sponge_b;
        o_q_b         : out sponge_b;
        o_q_c         : out sponge_b;
        o_q_d         : out sponge_b
    );
end entity lyra2_ram;

architecture rtl of lyra2_ram is

    type ram_fsm is (Read, Write);
    signal FSM : ram_fsm := Read;

    -- Read address buffer
    signal rdaddress_a : ram_address;
    signal rdaddress_b : ram_address;
    signal rdaddress_c : ram_address;
    signal rdaddress_d : ram_address;

    -- MUX'ed read/writes
    signal address_a            : ram_address;
    signal address_b            : ram_address;
    signal address_c            : ram_address;
    signal address_d            : ram_address;
    signal rden, wren_a, wren_b : std_logic;

begin

    P_FSM : process(i_clk2x, i_reset) is
    begin
        if i_reset = '1' then
            FSM <= Read; 
        elsif rising_edge(i_clk2x) then
            case FSM is
                when Read  => FSM <= Write;
                when Write => FSM <= Read;
            end case;
        end if;
    end process P_FSM;

    P_RD_BUFF : process(i_clk) is
    begin
        if rising_edge(i_clk) then
            rdaddress_a <= i_rdaddress_a;
            rdaddress_b <= i_rdaddress_b;
            rdaddress_c <= i_rdaddress_c;
            rdaddress_d <= i_rdaddress_d;
        end if;
    end process P_RD_BUFF;

    P_MULTIPUMP : process(FSM, i_wraddress_a, i_wraddress_b, i_wren_a, i_wren_b, rdaddress_a, rdaddress_b, rdaddress_c, rdaddress_d)
    begin
        case FSM is
            when Read =>
                rden      <= '1';
                wren_a    <= '0';
                wren_b    <= '0';
                address_a <= rdaddress_a;
                address_b <= rdaddress_b;
                address_c <= rdaddress_c;
                address_d <= rdaddress_d;

            when Write =>
                rden      <= '0';
                wren_a    <= i_wren_a;
                wren_b    <= i_wren_b;
                address_a <= i_wraddress_a;
                address_b <= i_wraddress_b;
                address_c <= i_wraddress_a;
                address_d <= i_wraddress_b;
        end case;
    end process P_MULTIPUMP;

    RAM_A : entity work.lyra2_tdpram
        generic map(MEMORY_PRIMITIVE => "block")
        port map(
            address_a => address_a,
            address_b => address_b,
            clk       => i_clk2x,
            data_a    => i_data_a,
            data_b    => i_data_b,
            rden_a    => rden,
            rden_b    => rden,
            wren_a    => wren_a,
            wren_b    => wren_b,
            q_a       => o_q_a,
            q_b       => o_q_b
        );

    RAM_B : entity work.lyra2_tdpram
        generic map(MEMORY_PRIMITIVE => "auto")
        port map(
            address_a => address_c,
            address_b => address_d,
            clk       => i_clk2x,
            data_a    => i_data_a,
            data_b    => i_data_b,
            rden_a    => rden,
            rden_b    => rden,
            wren_a    => wren_a,
            wren_b    => wren_b,
            q_a       => o_q_c,
            q_b       => o_q_d
        );

end architecture rtl;
