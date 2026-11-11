# --- 1. Creare biblioteca de lucru ---
vlib work
vmap work work

# --- 2. Compilare module VHDL in ordinea dependentelor ---
# Inmultitor Booth Radix-4
vcom -2008 -work work ../src/booth_radix4_cu.vhd
vcom -2008 -work work ../src/booth_radix4_eu.vhd
vcom -2008 -work work ../src/booth_multiplier_top.vhd

# Impartitor Radix-4 SRT
vcom -2008 -work work ../src/srt_radix4_cu.vhd
vcom -2008 -work work ../src/srt_radix4_eu.vhd
vcom -2008 -work work ../src/srt_divider_top.vhd

# Top-Level Integrat si Testbench-uri
vcom -2008 -work work ../src/math_unit_top.vhd
vcom -2008 -work work ../tb/tb_booth_radix4.vhd
vcom -2008 -work work ../tb/tb_srt_radix4.vhd
vcom -2008 -work work ../tb/tb_math_unit.vhd

# --- 3. Pornire simulare pentru Testbench-ul Inmultitorului ---
vsim -t 1ns work.tb_booth_radix4

# --- 4. Adaugare semnale pe diagrama de unda (Wave) ---
add wave -divider "Top Level Signals"
add wave -position insertpoint sim:/tb_booth_radix4/clk
add wave -position insertpoint sim:/tb_booth_radix4/reset
add wave -position insertpoint sim:/tb_booth_radix4/start
add wave -radix decimal  sim:/tb_booth_radix4/multiplicand
add wave -radix decimal  sim:/tb_booth_radix4/multiplier
add wave -radix decimal  sim:/tb_booth_radix4/product
add wave -position insertpoint sim:/tb_booth_radix4/done

add wave -divider "CU State Machine"
add wave -position insertpoint sim:/tb_booth_radix4/UUT/CU_INST/current_state

# --- 5. Rulare simulare automat ---
run -all