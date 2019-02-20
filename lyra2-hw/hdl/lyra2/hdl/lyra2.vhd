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
-- This file contains the Lyra2 control and the datapath entities.        *
--                                                                        *               
--*************************************************************************


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.lyra2_pkg.all;

entity lyra2 is
	port(
		i_reset   : in  std_logic;
		i_clk     : in  std_logic;
		i_clk2x   : in  std_logic;
		i_din     : in  std_logic_vector(HWIDTH - 1 downto 0); -- pwd & salt
		i_din_rdy : in  std_logic;
		o_din_rd  : out std_logic;
		o_dout    : out std_logic_vector(HWIDTH - 1 downto 0);
		o_dout_wr : out std_logic
	);
end entity lyra2;

architecture rtl of lyra2 is

	----------------------------------------------------------------------------
	-- Types
	----------------------------------------------------------------------------

	type lyra2_fsm is (Stop, Boot00, Boot01, Boot10, Boot11, Setup0, Setup1, Setup2, Wander, Wrap0, Wrap1);
	type row_array is array (0 to NPPL - 1) of row_cnt;
	type addr_ppl is array (natural range <>) of ram_address;
	type en_ppl is array (natural range <>) of std_logic;

	----------------------------------------------------------------------------
	-- Registers
	----------------------------------------------------------------------------

	-- FSM
	signal FSM : lyra2_fsm := Stop;

	-- row and column counters for M
	signal row0, row1, prev0 : row_cnt   := (others => '0');
	signal row1_det          : row_cnt   := (others => '0');
	signal row1_rand_array   : row_array := (others => (others => '0'));

	signal col : col_cnt := (others => '0');

	-- round counter for full-round sponge
	signal round : natural range 0 to NROUND - 1 := 0;

	-- pipeline counter
	signal ppl : natural range 0 to NPPL - 1 := NPPL - 1;

	-- sponge input
	signal sponge_sel_ppl : en_ppl(0 to 1) := (others => '0');

	-- RAM control pipelines
	signal wraddress_a_ppl, wraddress_b_ppl : addr_ppl(0 to NPPL - 1);
	signal rdaddress_c_ppl                  : addr_ppl(0 to NPPL - 3);
	signal wren_a_ppl, wren_b_ppl           : en_ppl(0 to NPPL - 1) := (others => '0');

	-- output write pipeline
	signal dout_wr_ppl : en_ppl(0 to NPPL - 1) := (others => '0');

	----------------------------------------------------------------------------
	-- Internal signals
	----------------------------------------------------------------------------

	-- Sponge
	signal sponge_clr  : std_logic;
	signal sponge_sel  : std_logic;
	signal sponge_dout : sponge_b;

	-- RAM
	signal rdaddress_a, rdaddress_b : ram_address;
	signal rdaddress_c, rdaddress_d : ram_address;
	signal wraddress_a, wraddress_b : ram_address;
	signal wren_a, wren_b           : std_logic;
	signal data_a, data_b           : sponge_b;
	signal q_a, q_b, q_c, q_d       : sponge_b;

	signal row1_rand : row_cnt;

	-- Arithmetic
	signal addw_in1, addw_out : sponge_b;
	signal xor1_out           : sponge_b;
	signal xor2_out, xor2_in1 : sponge_b;
	signal col_inv            : col_cnt;

	-- Booleans
	signal col_max, col_min, row_max, matrix_max, round_max, ppl_max : boolean;
	signal wr_overlap                                                : boolean;

	signal dout_wr : std_logic;

	----------------------------------------------------------------------------
	-- Helper functions
	----------------------------------------------------------------------------

	-- Fixed rotate
	function rotW(b_in : sponge_b) return sponge_b is
	begin
		return std_logic_vector(unsigned(b_in) rol WWIDTH);
	end function rotW;

	-- Matrix addresses
	function address(ppl : natural; row, col : unsigned) return ram_address is
		variable tmp     : std_logic_vector(RAM_WIDTH - row'length - col'length + row'length + col'length - 1 downto 0);
		variable tmp_rev : std_logic_vector(tmp'reverse_range);
	begin
		tmp := std_logic_vector(to_unsigned(ppl, RAM_WIDTH - row'length - col'length)) & std_logic_vector(row) & std_logic_vector(col);
		for i in tmp'range loop
			tmp_rev(i) := tmp(tmp'left - i);
		end loop;
		return tmp_rev;
	end function address;

begin

	-- Output
	o_din_rd  <= sponge_sel;
	o_dout    <= sponge_dout(HWIDTH - 1 downto 0);
	o_dout_wr <= dout_wr;
	dout_wr   <= dout_wr_ppl(dout_wr_ppl'high);

	-- RAM  
	data_a <= xor1_out;
	data_b <= xor2_out;

	P_RAM_WR_A : process(i_clk, i_reset)
	begin
		if i_reset = '1' then
			wren_a_ppl <= (others => '0');
		elsif rising_edge(i_clk) then

			wraddress_a_ppl(1 to wraddress_a_ppl'high) <= wraddress_a_ppl(0 to wraddress_a_ppl'high - 1);
			wren_a_ppl(1 to wren_a_ppl'high)           <= wren_a_ppl(0 to wren_a_ppl'high - 1);

			case FSM is
				when Boot11 =>
					wraddress_a_ppl(0) <= address(ppl, row0, col_inv);
					if round_max then
						wren_a_ppl(0) <= '1';
					else
						wren_a_ppl(0) <= '0';
					end if;
				when Setup0 =>
					wraddress_a_ppl(0) <= address(ppl, row0, col_inv);
					if col_min then
						wren_a_ppl(0) <= '0';
					else
						wren_a_ppl(0) <= '1';
					end if;
				when Setup1|Setup2 =>
					wraddress_a_ppl(0) <= address(ppl, row0, col_inv);
					wren_a_ppl(0)      <= '1';
				when Wander =>
					wraddress_a_ppl(0) <= address(ppl, row0, col);
					if wr_overlap then
						wren_a_ppl(0) <= '0';
					else
						wren_a_ppl(0) <= '1';
					end if;
				when others =>
					wraddress_a_ppl(0) <= address(ppl, row0, col);
					wren_a_ppl(0)      <= '0';
			end case;

		end if;
	end process P_RAM_WR_A;

	P_RAM_WR_B : process(i_clk, i_reset)
	begin
		if i_reset = '1' then
			wren_b_ppl <= (others => '0');
		elsif rising_edge(i_clk) then

			wraddress_b_ppl(1 to wraddress_b_ppl'high) <= wraddress_b_ppl(0 to wraddress_b_ppl'high - 1);
			wren_b_ppl(1 to wren_b_ppl'high)           <= wren_b_ppl(0 to wren_b_ppl'high - 1);

			case FSM is
				when Setup2|Wander => wren_b_ppl(0) <= '1';
				when others        => wren_b_ppl(0) <= '0';
			end case;

			wraddress_b_ppl(0) <= address(ppl, row1, col);

		end if;
	end process P_RAM_WR_B;

	P_RAM_RD_A : process(FSM, col, ppl, prev0)
	begin
		case FSM is
			when Stop|Boot00|Boot01|Boot11|Setup0|Wrap0|Wrap1 => rdaddress_a <= ZEROS_ADDRESS;
			when Boot10                                       => rdaddress_a <= PARAM_ADDRESS;
			when Setup1|Setup2|Wander                         => rdaddress_a <= address(ppl, prev0, col);
		end case;
	end process P_RAM_RD_A;

	P_RAM_RD_B : process(FSM, col, ppl, row1)
	begin
		case FSM is
			when Stop|Boot00|Boot10|Boot01|Boot11|Setup0|Setup1|Wrap1 => rdaddress_b <= ZEROS_ADDRESS;
			when Setup2|Wander|Wrap0                                  => rdaddress_b <= address(ppl, row1, col);
		end case;
	end process P_RAM_RD_B;

	P_RAM_RD_C_PPL : process(i_clk)
	begin
		if rising_edge(i_clk) then

			rdaddress_c_ppl(1 to rdaddress_c_ppl'high) <= rdaddress_c_ppl(0 to rdaddress_c_ppl'high - 1);

			case FSM is
				when Stop|Boot00|Boot10|Boot01|Boot11|Setup0|Wrap0|Wrap1 => rdaddress_c_ppl(0) <= ZEROS_ADDRESS;
				when Setup1|Setup2                                       => rdaddress_c_ppl(0) <= address(ppl, prev0, col);
				when Wander                                              => rdaddress_c_ppl(0) <= address(ppl, row0, col);

			end case;
		end if;
	end process P_RAM_RD_C_PPL;

	wraddress_a <= wraddress_a_ppl(wraddress_a_ppl'high);
	wraddress_b <= wraddress_b_ppl(wraddress_b_ppl'high);
	rdaddress_c <= rdaddress_c_ppl(rdaddress_c_ppl'high);
	rdaddress_d <= wraddress_b_ppl(rdaddress_c_ppl'high);
	wren_a      <= wren_a_ppl(wren_a_ppl'high);
	wren_b      <= wren_b_ppl(wren_b_ppl'high);

	-- Counters
	P_PPL : process(i_clk)
	begin
		if rising_edge(i_clk) then
			if ppl_max then
				ppl <= 0;
			else
				ppl <= ppl + 1;
			end if;
		end if;
	end process P_PPL;

	P_ROW0COL : process(i_clk)
	begin
		if rising_edge(i_clk) then
			if ppl_max then
				if (FSM = Setup1) or (FSM = Setup2) or (FSM = Wander) or (FSM = Boot11 and round_max) or (FSM = Setup0 and not col_min) then
					col <= col + 1;
					if col_max then
						row0     <= row0 + 1;
						prev0    <= row0;
						row1_det <= prev0;

					end if;
				end if;
			end if;
		end if;
	end process P_ROW0COL;

	col_inv <= not col;

	P_ROW1 : process(FSM, col_min, ppl, row1_det, row1_rand, row1_rand_array)
	begin
		case FSM is
			when Wander =>
				if col_min then
					row1 <= row1_rand;
				else
					row1 <= row1_rand_array(ppl);
				end if;
			when Wrap0 =>
				row1 <= row1_rand_array(ppl);
			when others =>
				row1 <= row1_det;
		end case;
	end process P_ROW1;

	row1_rand <= unsigned(sponge_dout(1 downto 0));

	P_ROW1_RAND_ARRAY : process(i_clk)
	begin
		if rising_edge(i_clk) then
			if col_min then
				row1_rand_array(ppl) <= row1_rand;
			end if;
		end if;
	end process P_ROW1_RAND_ARRAY;

	-- Sponge
	P_SPONGE_SEL : process(i_clk)
	begin
		if rising_edge(i_clk) then
			sponge_sel_ppl(0) <= sponge_clr;
			sponge_sel_ppl(1) <= sponge_sel_ppl(0);
		end if;
	end process P_SPONGE_SEL;

	sponge_sel <= sponge_sel_ppl(sponge_sel_ppl'high);
	sponge_clr <= '1' when FSM = Boot00 else '0';

	P_ADDW_DIN : process(sponge_sel, i_din, q_a)
	begin
		addw_in1 <= q_a;
		if sponge_sel = '1' then
			addw_in1(511 downto 0) <= i_din & i_din;
		end if;

	end process P_ADDW_DIN;

	P_RND : process(i_clk)
	begin
		if rising_edge(i_clk) then
			if ppl_max then
				case FSM is
					when Boot01|Boot11|Wrap1 =>
						if round_max then
							round <= 0;
						else
							round <= round + 1;
						end if;
					when others => null;
				end case;
			end if;
		end if;
	end process P_RND;

	-- FSM
	P_FSM_NSL : process(i_clk, i_reset)
	begin
		if (i_reset = '1') then
			FSM <= Stop;
		elsif rising_edge(i_clk) then
			if ppl_max then
				case FSM is
					when Stop =>
						if i_din_rdy = '1' then
							FSM <= Boot00;
						end if;
					when Boot00 =>
						FSM <= Boot01;
					when Boot01 =>
						if round_max then
							FSM <= Boot10;
						end if;
					when Boot10 =>
						FSM <= Boot11;
					when Boot11 =>
						if round_max then
							FSM <= Setup0;
						end if;
					when Setup0 =>
						if col_min then
							FSM <= Setup1;
						end if;
					when Setup1 =>
						if col_max then
							FSM <= Setup2;
						end if;
					when Setup2 =>
						if matrix_max then
							FSM <= Wander;
						end if;
					when Wander =>
						if matrix_max then
							FSM <= Wrap0;
						end if;
					When Wrap0 =>
						FSM <= Wrap1;
					when Wrap1 =>
						if round_max then
							if i_din_rdy = '1' then
								FSM <= Boot00;
							else
								FSM <= Stop;
							end if;
						end if;
				end case;
			end if;
		end if;
	end process P_FSM_NSL;

	P_D_OUT_WR : process(i_clk)
	begin
		if rising_edge(i_clk) then
			dout_wr_ppl(1 to dout_wr_ppl'high) <= dout_wr_ppl(0 to dout_wr_ppl'high - 1);
			if FSM = Wrap1 and round_max then
				dout_wr_ppl(0) <= '1';
			else
				dout_wr_ppl(0) <= '0';
			end if;
		end if;
	end process P_D_OUT_WR;

	-- Datapath
	SPONGE : entity work.lyra2_sponge
		port map(
			clk    => i_clk,
			i_clr  => sponge_clr,
			i_din  => addw_out,
			o_dout => sponge_dout
		);

	RAM : entity work.lyra2_ram
		port map(
			i_reset       => i_reset,
			i_clk         => i_clk,
			i_clk2x       => i_clk2x,
			i_wraddress_a => wraddress_a,
			i_wraddress_b => wraddress_b,
			i_rdaddress_a => rdaddress_a,
			i_rdaddress_b => rdaddress_b,
			i_rdaddress_c => rdaddress_c,
			i_rdaddress_d => rdaddress_d,
			i_data_a      => data_a,
			i_data_b      => data_b,
			i_wren_a      => wren_a,
			i_wren_b      => wren_b,
			o_q_a         => q_a,
			o_q_b         => q_b,
			o_q_c         => q_c,
			o_q_d         => q_d
		);

	ADDW : entity work.lyra2_addw
		port map(
			i_a => addw_in1,
			i_b => q_b,
			o_c => addw_out
		);
		
	XOR1 : xor1_out <= q_c xor sponge_dout;
	XOR2 : xor2_out <= xor2_in1 xor rotW(sponge_dout);
	xor2_in1 <= xor1_out when wren_a_ppl(wren_a_ppl'high) = '0' else q_d;

	-- Booleans
	col_max    <= col = (NCOL - 1);
	col_min    <= col = "00";
	row_max    <= row0 = (NROW - 1);
	matrix_max <= col_max and row_max;
	round_max  <= round = (NROUND - 2);
	ppl_max    <= ppl = (NPPL - 1);
	wr_overlap <= (row0 = row1);

end architecture rtl;

