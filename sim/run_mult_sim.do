# --- 1. Create and map work library ---
vlib work
vmap work work

# --- 2. Compile Multiplier VHDL source files ---
vcom -2008 -work work ../src/booth_radix4_cu.vhd
vcom -2008 -work work ../src/booth_radix4_eu.vhd
vcom -2008 -work work ../src/booth_multiplier_top.vhd

# --- 3. Compile Multiplier Testbench ---
vcom -2008 -work work ../tb/tb_booth_radix4.vhd

# --- 4. Start Simulation ---
vsim -t 1ns work.tb_booth_radix4

# --- 5. Add Waveform Signals ---
add wave -divider "Top Level Signals"
add wave -position insertpoint sim:/tb_booth_radix4/clk
add wave -position insertpoint sim:/tb_booth_radix4/reset
add wave -position insertpoint sim:/tb_booth_radix4/start
add wave -radix decimal  sim:/tb_booth_radix4/multiplicand
add wave -radix decimal  sim:/tb_booth_radix4/multiplier
add wave -radix decimal  sim:/tb_booth_radix4/product
add wave -position insertpoint sim:/tb_booth_radix4/ready
add wave -position insertpoint sim:/tb_booth_radix4/done

add wave -divider "CU State Machine"
add wave -position insertpoint sim:/tb_booth_radix4/UUT/CU_INST/current_state

# --- 6. Run Simulation ---
run -all