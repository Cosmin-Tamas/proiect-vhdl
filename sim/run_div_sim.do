# --- 1. Create and map work library ---
vlib work
vmap work work

# --- 2. Compile SRT Radix-4 Divider VHDL source files ---
vcom -2008 -work work ../src/srt_radix4_cu.vhd
vcom -2008 -work work ../src/srt_radix4_eu.vhd
vcom -2008 -work work ../src/srt_divider_top.vhd

# --- 3. Compile Divider Testbench ---
vcom -2008 -work work ../tb/tb_srt_radix4.vhd

# --- 4. Start Simulation ---
vsim -t 1ns work.tb_srt_radix4

# --- 5. Add Waveform Signals ---
add wave -divider "Top Level Signals"
add wave -position insertpoint sim:/tb_srt_radix4/clk
add wave -position insertpoint sim:/tb_srt_radix4/reset
add wave -position insertpoint sim:/tb_srt_radix4/start
add wave -radix decimal  sim:/tb_srt_radix4/dividend
add wave -radix decimal  sim:/tb_srt_radix4/divisor
add wave -radix decimal  sim:/tb_srt_radix4/quotient
add wave -radix decimal  sim:/tb_srt_radix4/remainder
add wave -position insertpoint sim:/tb_srt_radix4/ready
add wave -position insertpoint sim:/tb_srt_radix4/done

add wave -divider "CU State Machine"
add wave -position insertpoint sim:/tb_srt_radix4/UUT/CU_INST/current_state

# --- 6. Run Simulation ---
run -all