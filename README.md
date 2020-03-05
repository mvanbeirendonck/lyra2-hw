# A Lyra2 FPGA Core for Lyra2REv2-Based Cryptocurrencies

Copyright (C) 2018-2019 Michiel Van Beirendonck

Copyright (C) 2018-2019 Louis-Charles Trudeau

See LICENSE.txt

# Purpose

This repository provides source files for simulation and implementation of a Lyra2 FPGA core for Lyra2REv2-based cryptocurrencies. If you make use of any of these source files, we kindly ask you to cite our conference paper:

M. van Beirendonck, L. Trudeau, P. Giard and A. Balatsoukas-Stimming, "A Lyra2 FPGA Core for Lyra2REv2-Based Cryptocurrencies," 2019 IEEE International Symposium on Circuits and Systems (ISCAS), Sapporo, Japan, 2019, pp. 1-5.
https://doi.org/10.1109/ISCAS.2019.8702498

# Folder Structure

```bash
├── hdl				# HDL source files
│ ├── ...
│ └── lyra2
│   ├── hdl   
│   └── sim                     # Core-level simulation files
├── ip				# Xilinx IP configuration files
├── sim				# Top-level simulation files 
├── sw				# Software reference files and test vector generation
└── syn				# Synthesis files
```	

# Contributors

### Michiel van Beirendonck
imec-COSIC, KU Leuven, Leuven, Belgium

michiel.vanbeirendonck@esat.kuleuven.be
### Louis-Charles Trudeau
Formerly with the Electrical Engineering Department, Ecole de technologie supérieure (ETS), Montréal, Canada 
### Pascal Giard
Electrical Engineering Department, Ecole de technologie supérieure (ETS), Montréal, Canada 
### Alexios Balatsoukas-Stimming
Telecommunications Circuits Laboratory, Ecole polytechnique fédérale de Lausanne (EPFL), Lausanne, Switzerland
