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
-- This file contains the Lyra2 package.                                  *
--                                                                        *               
--*************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.ceil;
use ieee.math_real.log2;

package lyra2_pkg is

    constant HWIDTH : integer := 256;   -- hash width

    -- Sponge
    constant SPONGE_SS : integer := 1024; -- state 
    constant SPONGE_BB : integer := 768; -- bitrate
    constant SPONGE_CC : integer := 256; -- capacity

    subtype sponge_s is std_logic_vector(SPONGE_SS - 1 downto 0); -- state
    subtype sponge_b is std_logic_vector(SPONGE_BB - 1 downto 0); -- bitrate

    -- BLAKE
    constant NROUND     : integer                        := 12;
    constant WWIDTH     : integer                        := 64;
    constant BLAKE2B_IV : std_logic_vector(511 downto 0) := X"5be0cd19137e2179" & 
                                                            X"1f83d9abfb41bd6b" & 
                                                            X"9b05688c2b3e6c1f" & 
                                                            X"510e527fade682d1" & 
                                                            X"a54ff53a5f1d36f1" & 
                                                            X"3c6ef372fe94f82b" & 
                                                            X"bb67ae8584caa73b" & 
                                                            X"6a09e667f3bcc908";

    subtype byte is std_logic_vector(7 downto 0);
    subtype uword is unsigned(WWIDTH - 1 downto 0);

    type uword_array is array (natural range <>) of uword;
    function std_to_uword_array(d_in : std_logic_vector) return uword_array;
    function uword_array_to_std(d_in : uword_array) return std_logic_vector;

    -- RAM
    constant NCOL : integer := 4;
    constant NROW : integer := 4;
    constant NPPL : integer := 8; -- number of stages from RAM read to write ports, reacrate lyra2_ram.mem if you change this value!

    constant RAM_DEPTH : integer := NCOL * NROW * NPPL + 2;
    constant RAM_SIZE  : integer := RAM_DEPTH * SPONGE_BB; --bits
    constant RAM_WIDTH : integer := integer(ceil(log2(real(RAM_DEPTH))));

    subtype ram_address is std_logic_vector(RAM_WIDTH - 1 downto 0);
    -- unsigned counters can use implicit wrap-around
    subtype row_cnt is unsigned(integer(ceil(log2(real(NCOL)))) - 1 downto 0);
    subtype col_cnt is unsigned(integer(ceil(log2(real(NROW)))) - 1 downto 0);

    -- RAM init
    constant KLEN_STD    : std_logic_vector := std_logic_vector(to_unsigned(32, WWIDTH));
    constant PWDLEN_STD  : std_logic_vector := std_logic_vector(to_unsigned(32, WWIDTH));
    constant SALTLEN_STD : std_logic_vector := std_logic_vector(to_unsigned(32, WWIDTH));
    constant T_STD       : std_logic_vector := std_logic_vector(to_unsigned(1, WWIDTH));
    constant NROW_STD    : std_logic_vector := std_logic_vector(to_unsigned(NROW, WWIDTH));
    constant NCOL_STD    : std_logic_vector := std_logic_vector(to_unsigned(NCOL, WWIDTH));

    constant PAD0    : byte                                        := X"80";
    constant PAD1    : std_logic_vector(495 - 6 * WWIDTH downto 0) := (others => '0');
    constant PAD2    : byte                                        := X"01";
    constant ZERO_IV : std_logic_vector(255 downto 0)              := (others => '0');

    constant SPONGE_BB_ZERO : sponge_b := (others => '0');
    constant SPONGE_PARAM   : sponge_b := ZERO_IV & PAD2 & PAD1 & PAD0 & NCOL_STD & NROW_STD & T_STD & SALTLEN_STD & PWDLEN_STD & KLEN_STD;

    constant ZEROS_ADDRESS : ram_address := std_logic_vector(to_unsigned(RAM_DEPTH - 2, RAM_WIDTH));
    constant PARAM_ADDRESS : ram_address := std_logic_vector(to_unsigned(RAM_DEPTH - 1, RAM_WIDTH));

end package lyra2_pkg;

package body lyra2_pkg is

    function std_to_uword_array(d_in : std_logic_vector) return uword_array is
        constant length : natural := (d_in'length / WWIDTH);
        variable d_out  : uword_array(0 to length - 1);
    begin
        for i in 0 to length - 1 loop
            d_out(i) := unsigned(d_in((i + 1) * WWIDTH - 1 downto i * WWIDTH));
        end loop;
        return d_out;
    end function std_to_uword_array;

    function uword_array_to_std(d_in : uword_array) return std_logic_vector is
        constant length : natural := d_in'length;
        variable d_out  : std_logic_vector(length * WWIDTH - 1 downto 0);
    begin
        for i in 0 to length - 1 loop
            d_out((i + 1) * WWIDTH - 1 downto i * WWIDTH) := std_logic_vector(d_in(i));
        end loop;
        return d_out;
    end function uword_array_to_std;

end package body lyra2_pkg;

