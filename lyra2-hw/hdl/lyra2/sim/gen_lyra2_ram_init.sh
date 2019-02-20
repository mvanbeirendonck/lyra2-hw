#!/bin/sh

# Generates the BRAM initialization file for the current number of pipeline stages in lyra2_pkg.vhd

NPPL=`grep "constant NPPL" ../hdl/lyra2_pkg.vhd | cut -d "=" -f 2 | cut -d ";" -f 2 --complement`
echo "Generating the BRAM initialization for $NPPL pipeline stages"
truncate -s 0 lyra2_ram.mem

for i in `seq 0 $(($NPPL*4*4))`
do
	for j in `seq 0 190`
	do
		echo -n "0" >> lyra2_ram.mem
	done
	echo "0" >> lyra2_ram.mem
done

echo "000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000080000000000000000400000000000000040000000000000001000000000000002000000000000000200000000000000020" >> lyra2_ram.mem
