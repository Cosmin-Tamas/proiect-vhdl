# --- 1. Create and map work library ---
vlib work
vmap work work

# --- 2. Compile all VHDL source files in dependency order ---
# Radix-4 Booth Multiplier
vcom -2008 -work work ../src/booth_radix4_cu.vhd
vcom -2008 -work work ../src/booth_radix4_eu.vhd
vcom -2008 -work work ../src/booth_multiplier_top.vhd

# Radix-4 SRT Divider
vcom -2008 -work work ../src/srt_radix4_cu.vhd
vcom -2008 -work work ../src/srt_radix4_eu.vhd
vcom -2008 -work work ../src/srt_divider_top.vhd

# Integrated Top-Level & All Testbenches
vcom -2008 -work work ../src/math_unit_top.vhd
vcom -2008 -work work ../tb/tb_booth_radix4.vhd
vcom -2008 -work work ../tb/tb_srt_radix4.vhd
vcom -2008 -work work ../tb/tb_math_unit.vhd

# --- 3. Start Integrated System Simulation ---
vsim -t 1ns work.tb_math_unit

# --- 4. Add Waveform Signals ---
add wave -divider "Integrated Top-Level Signals"
add wave -position insertpoint sim:/tb_math_unit/clk
add wave -position insertpoint sim:/tb_math_unit/reset
add wave -position insertpoint sim:/tb_math_unit/start
add wave -position insertpoint sim:/tb_math_unit/op_sel
add wave -radix decimal  sim:/tb_math_unit/operand_a
add wave -radix decimal  sim:/tb_math_unit/operand_b
add wave -radix decimal  sim:/tb_math_unit/result
add wave -radix decimal  sim:/tb_math_unit/UUT/sig_div_quot
add wave -radix decimal  sim:/tb_math_unit/UUT/sig_div_rem
add wave -position insertpoint sim:/tb_math_unit/div_zero_err
add wave -position insertpoint sim:/tb_math_unit/ready
add wave -position insertpoint sim:/tb_math_unit/done

add wave -divider "Sub-Unit FSM States"
add wave -position insertpoint sim:/tb_math_unit/UUT/MULT_UNIT/CU_INST/current_state
add wave -position insertpoint sim:/tb_math_unit/UUT/DIV_UNIT/CU_INST/current_state

# --- 5. Run Simulation ---
run -all