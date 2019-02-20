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
-- This file contains the Lyra2 wrapper for Xilinx BRAM.                  *
--                                                                        *               
--*************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;

use std.textio.all;

use work.lyra2_pkg.all;

entity lyra2_tdpram is
	generic(MEMORY_PRIMITIVE : string);
	port(
		address_a : in  ram_address;
		address_b : in  ram_address;
		clk       : in  std_logic;
		data_a    : in  std_logic_vector(SPONGE_BB - 1 downto 0);
		data_b    : in  std_logic_vector(SPONGE_BB - 1 downto 0);
		rden_a    : in  std_logic;
		rden_b    : in  std_logic;
		wren_a    : in  std_logic;
		wren_b    : in  std_logic;
		q_a       : out std_logic_vector(SPONGE_BB - 1 downto 0);
		q_b       : out std_logic_vector(SPONGE_BB - 1 downto 0)
	);
end entity lyra2_tdpram;

architecture xpm of lyra2_tdpram is
	signal wea, web : std_logic_vector(0 downto 0);
	signal ena, enb : std_logic;

	----- component xpm_memory_tdpram -----
	component xpm_memory_tdpram
		generic(
			-- Common module generics
			MEMORY_SIZE             : integer := 2048;
			MEMORY_PRIMITIVE        : string  := "auto";
			CLOCKING_MODE           : string  := "common_clock";
			ECC_MODE                : string  := "no_ecc";
			MEMORY_INIT_FILE        : string  := "none";
			MEMORY_INIT_PARAM       : string  := "";
			USE_MEM_INIT            : integer := 1;
			WAKEUP_TIME             : string  := "disable_sleep";
			AUTO_SLEEP_TIME         : integer := 0;
			MESSAGE_CONTROL         : integer := 0;
			USE_EMBEDDED_CONSTRAINT : integer := 0;
			MEMORY_OPTIMIZATION     : string  := "false";
			-- Port A module generics
			WRITE_DATA_WIDTH_A      : integer := 32;
			READ_DATA_WIDTH_A       : integer := 32;
			BYTE_WRITE_WIDTH_A      : integer := 32;
			ADDR_WIDTH_A            : integer := 6;
			READ_RESET_VALUE_A      : string  := "0";
			READ_LATENCY_A          : integer := 2;
			WRITE_MODE_A            : string  := "no_change";
			-- Port B module generics
			WRITE_DATA_WIDTH_B      : integer := 32;
			READ_DATA_WIDTH_B       : integer := 32;
			BYTE_WRITE_WIDTH_B      : integer := 32;
			ADDR_WIDTH_B            : integer := 6;
			READ_RESET_VALUE_B      : string  := "0";
			READ_LATENCY_B          : integer := 2;
			WRITE_MODE_B            : string  := "no_change"
		);
		port(
			-- Common module ports
			sleep          : in  std_logic;
			-- Port A module ports
			clka           : in  std_logic;
			rsta           : in  std_logic;
			ena            : in  std_logic;
			regcea         : in  std_logic;
			wea            : in  std_logic_vector((WRITE_DATA_WIDTH_A / BYTE_WRITE_WIDTH_A) - 1 downto 0);
			addra          : in  std_logic_vector(ADDR_WIDTH_A - 1 downto 0);
			dina           : in  std_logic_vector(WRITE_DATA_WIDTH_A - 1 downto 0);
			injectsbiterra : in  std_logic;
			injectdbiterra : in  std_logic;
			douta          : out std_logic_vector(READ_DATA_WIDTH_A - 1 downto 0);
			sbiterra       : out std_logic;
			dbiterra       : out std_logic;
			-- Port B module ports
			clkb           : in  std_logic;
			rstb           : in  std_logic;
			enb            : in  std_logic;
			regceb         : in  std_logic;
			web            : in  std_logic_vector((WRITE_DATA_WIDTH_B / BYTE_WRITE_WIDTH_B) - 1 downto 0);
			addrb          : in  std_logic_vector(ADDR_WIDTH_B - 1 downto 0);
			dinb           : in  std_logic_vector(WRITE_DATA_WIDTH_B - 1 downto 0);
			injectsbiterrb : in  std_logic;
			injectdbiterrb : in  std_logic;
			doutb          : out std_logic_vector(READ_DATA_WIDTH_B - 1 downto 0);
			sbiterrb       : out std_logic;
			dbiterrb       : out std_logic
		);
	end component;

begin

	wea(0) <= wren_a;
	web(0) <= wren_b;

	ena <= rden_a or wren_a;
	enb <= rden_b or wren_b;

	xpm_memory_tdpram_inst : xpm_memory_tdpram
		generic map(
			ADDR_WIDTH_A            => RAM_WIDTH, -- DECIMAL
			ADDR_WIDTH_B            => RAM_WIDTH, -- DECIMAL
			AUTO_SLEEP_TIME         => 0, -- DECIMAL
			BYTE_WRITE_WIDTH_A      => SPONGE_BB, -- DECIMAL
			BYTE_WRITE_WIDTH_B      => SPONGE_BB, -- DECIMAL
			CLOCKING_MODE           => "common_clock", -- String
			ECC_MODE                => "no_ecc", -- String
			MEMORY_INIT_FILE        => "lyra2_ram.mem", -- String
			MEMORY_INIT_PARAM       => "", -- String
			MEMORY_OPTIMIZATION     => "true", -- String
			MEMORY_PRIMITIVE        => MEMORY_PRIMITIVE, -- String
			MEMORY_SIZE             => RAM_SIZE, -- DECIMAL
			MESSAGE_CONTROL         => 0, -- DECIMAL
			READ_DATA_WIDTH_A       => SPONGE_BB, -- DECIMAL
			READ_DATA_WIDTH_B       => SPONGE_BB, -- DECIMAL
			READ_LATENCY_A          => 2, -- DECIMAL
			READ_LATENCY_B          => 2, -- DECIMAL
			READ_RESET_VALUE_A      => "0", -- String
			READ_RESET_VALUE_B      => "0", -- String
			USE_EMBEDDED_CONSTRAINT => 0, -- DECIMAL
			USE_MEM_INIT            => 1, -- DECIMAL
			WAKEUP_TIME             => "disable_sleep", -- String
			WRITE_DATA_WIDTH_A      => SPONGE_BB, -- DECIMAL
			WRITE_DATA_WIDTH_B      => SPONGE_BB, -- DECIMAL
			WRITE_MODE_A            => "no_change", -- String
			WRITE_MODE_B            => "no_change" -- String
		)
		port map(
			dbiterra       => open,     -- 1-bit output: Status signal to indicate double bit error occurrence
			                            -- on the data output of port A.

			dbiterrb       => open,     -- 1-bit output: Status signal to indicate double bit error occurrence
			                            -- on the data output of port A.

			douta          => q_a,      -- READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
			doutb          => q_b,      -- READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
			sbiterra       => open,     -- 1-bit output: Status signal to indicate single bit error occurrence
			                            -- on the data output of port A.

			sbiterrb       => open,     -- 1-bit output: Status signal to indicate single bit error occurrence
			                            -- on the data output of port B.

			addra          => address_a, -- ADDR_WIDTH_A-bit input: Address for port A write and read operations.
			addrb          => address_b, -- ADDR_WIDTH_B-bit input: Address for port B write and read operations.
			clka           => clk,      -- 1-bit input: Clock signal for port A. Also clocks port B when
			                            -- parameter CLOCKING_MODE is "common_clock".

			clkb           => '0',      -- 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
			                            -- "independent_clock". Unused when parameter CLOCKING_MODE is
			                            -- "common_clock".

			dina           => data_a,   -- WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
			dinb           => data_b,   -- WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
			ena            => ena,      -- 1-bit input: Memory enable signal for port A. Must be high on clock
			                            -- cycles when read or write operations are initiated. Pipelined
			                            -- internally.

			enb            => enb,      -- 1-bit input: Memory enable signal for port B. Must be high on clock
			                            -- cycles when read or write operations are initiated. Pipelined
			                            -- internally.

			injectdbiterra => '0',      -- 1-bit input: Controls double bit error injection on input data when
			                            -- ECC enabled (Error injection capability is not available in
			                            -- "decode_only" mode).

			injectdbiterrb => '0',      -- 1-bit input: Controls double bit error injection on input data when
			                            -- ECC enabled (Error injection capability is not available in
			                            -- "decode_only" mode).

			injectsbiterra => '0',      -- 1-bit input: Controls single bit error injection on input data when
			                            -- ECC enabled (Error injection capability is not available in
			                            -- "decode_only" mode).

			injectsbiterrb => '0',      -- 1-bit input: Controls single bit error injection on input data when
			                            -- ECC enabled (Error injection capability is not available in
			                            -- "decode_only" mode).

			regcea         => '1',      -- 1-bit input: Clock Enable for the last register stage on the output
			                            -- data path.

			regceb         => '1',      -- 1-bit input: Clock Enable for the last register stage on the output
			                            -- data path.

			rsta           => '0',      -- 1-bit input: Reset signal for the final port A output register
			                            -- stage. Synchronously resets output port douta to the value specified
			                            -- by parameter READ_RESET_VALUE_A.

			rstb           => '0',      -- 1-bit input: Reset signal for the final port B output register
			                            -- stage. Synchronously resets output port doutb to the value specified
			                            -- by parameter READ_RESET_VALUE_B.

			sleep          => '0',      -- 1-bit input: sleep signal to enable the dynamic power saving feature.

			wea            => wea,      -- WRITE_DATA_WIDTH_A-bit input: Write enable vector for port A input
			                            -- data port dina. 1 bit wide when word-wide writes are used. In
			                            -- byte-wide write configurations, each bit controls the writing one
			                            -- byte of dina to address addra. For example, to synchronously write
			                            -- only bits [15-8] of dina when WRITE_DATA_WIDTH_A is 32, wea would be
			                            -- 4'b0010.

			web            => web       -- WRITE_DATA_WIDTH_B-bit input: Write enable vector for port B input
			                            -- data port dinb. 1 bit wide when word-wide writes are used. In
			                            -- byte-wide write configurations, each bit controls the writing one
			                            -- byte of dinb to address addrb. For example, to synchronously write
			                            -- only bits [15-8] of dinb when WRITE_DATA_WIDTH_B is 32, web would be
			                            -- 4'b0010.

		);

end architecture xpm;
