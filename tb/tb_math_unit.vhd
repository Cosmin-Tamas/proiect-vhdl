----------------------------------------------------------------------------------
-- File: tb_math_unit.vhd
-- Description: Integrated System Testbench for the 16-bit Arithmetic Unit
--              (math_unit_top). Verifies interleaved signed multiplication
--              (Radix-4 Booth, op_sel = '0') and signed division (Radix-4 SRT,
--              op_sel = '1'), including divide-by-zero error signaling.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_math_unit is
end entity tb_math_unit;

architecture Test of tb_math_unit is
    constant DATA_WIDTH : integer := 16;
    constant CLK_PERIOD : time := 10 ns;

    -- UUT Signals
    signal clk          : std_logic := '0';
    signal reset        : std_logic := '0';
    signal start        : std_logic := '0';
    signal op_sel       : std_logic := '0';
    signal operand_a    : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal operand_b    : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal ready        : std_logic;
    signal done         : std_logic;
    signal div_zero_err : std_logic;
    signal result       : std_logic_vector((2 * DATA_WIDTH)-1 downto 0);

begin

    -- Instantiate Integrated Unit Under Test (UUT)
    UUT: entity work.math_unit_top
        generic map (
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            clk          => clk,
            reset        => reset,
            start        => start,
            op_sel       => op_sel,
            operand_a    => operand_a,
            operand_b    => operand_b,
            ready        => ready,
            done         => done,
            div_zero_err => div_zero_err,
            result       => result
        );

    -- Clock Generator Process (100 MHz)
    clk_process : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- Stimuli and Automated Verification Process
    stim_proc: process
        -- Helper procedure for signed multiplication (op_sel = '0')
        procedure run_mult(val_a, val_b : in integer) is
            variable expected : integer;
            variable actual   : integer;
        begin
            op_sel <= '0';
            wait until rising_edge(clk);

            if ready /= '1' then
                wait until ready = '1';
            end if;

            wait until rising_edge(clk);
            operand_a <= std_logic_vector(to_signed(val_a, DATA_WIDTH));
            operand_b <= std_logic_vector(to_signed(val_b, DATA_WIDTH));
            start     <= '1';
            wait until rising_edge(clk);
            start     <= '0';

            wait until done = '1';
            wait for 1 ns;

            expected := val_a * val_b;
            actual   := to_integer(signed(result));

            assert (actual = expected) and (div_zero_err = '0')
                report "MULT TEST FAILED: " & integer'image(val_a) & " * " & integer'image(val_b) &
                       " | Got: " & integer'image(actual) &
                       " | Expected: " & integer'image(expected)
                severity error;

            if (actual = expected) and (div_zero_err = '0') then
                report "MULT TEST PASSED: " & integer'image(val_a) & " * " & integer'image(val_b) &
                       " = " & integer'image(expected)
                       severity note;
            end if;

            wait for 20 ns;
        end procedure;

        -- Helper procedure for signed division (op_sel = '1')
        procedure run_div(val_a, val_b : in integer) is
            variable expected_q : integer;
            variable expected_r : integer;
            variable actual_q   : integer;
            variable actual_r   : integer;
        begin
            op_sel <= '1';
            wait until rising_edge(clk);

            if ready /= '1' then
                wait until ready = '1';
            end if;

            wait until rising_edge(clk);
            operand_a <= std_logic_vector(to_signed(val_a, DATA_WIDTH));
            operand_b <= std_logic_vector(to_signed(val_b, DATA_WIDTH));
            start     <= '1';
            wait until rising_edge(clk);
            start     <= '0';

            wait until done = '1';
            wait for 1 ns;

            expected_q := val_a / val_b;
            expected_r := val_a rem val_b;
            actual_q   := to_integer(signed(result(DATA_WIDTH-1 downto 0)));
            actual_r   := to_integer(signed(result((2*DATA_WIDTH)-1 downto DATA_WIDTH)));

            assert (actual_q = expected_q) and (actual_r = expected_r) and (div_zero_err = '0')
                report "DIV TEST FAILED: " & integer'image(val_a) & " / " & integer'image(val_b) &
                       " | Got Q=" & integer'image(actual_q) & ", R=" & integer'image(actual_r) &
                       " | Expected Q=" & integer'image(expected_q) & ", R=" & integer'image(expected_r)
                severity error;

            if (actual_q = expected_q) and (actual_r = expected_r) and (div_zero_err = '0') then
                report "DIV TEST PASSED: " & integer'image(val_a) & " / " & integer'image(val_b) &
                       " -> Q=" & integer'image(expected_q) & ", R=" & integer'image(expected_r)
                       severity note;
            end if;

            wait for 20 ns;
        end procedure;

        -- Helper procedure for divide-by-zero check (op_sel = '1')
        procedure run_div_zero(val_a : in integer) is
        begin
            op_sel <= '1';
            wait until rising_edge(clk);

            if ready /= '1' then
                wait until ready = '1';
            end if;

            wait until rising_edge(clk);
            operand_a <= std_logic_vector(to_signed(val_a, DATA_WIDTH));
            operand_b <= (others => '0');
            start     <= '1';
            wait until rising_edge(clk);
            start     <= '0';

            wait until done = '1';
            wait for 1 ns;

            assert div_zero_err = '1'
                report "DIV-BY-ZERO TEST FAILED: div_zero_err was not asserted!"
                severity error;

            if div_zero_err = '1' then
                report "DIV-BY-ZERO TEST PASSED: " & integer'image(val_a) & " / 0 -> div_zero_err = '1'"
                       severity note;
            end if;

            wait for 20 ns;
        end procedure;

    begin
        -- Apply initial reset
        reset <= '1';
        wait for 25 ns;
        reset <= '0';
        wait for 20 ns;

        -- Interleaved Operations Verification
        run_mult(250, 40);         -- 250 * 40 = 10000
        run_div(10000, 35);        -- 10000 / 35 -> Q = 285, R = 25
        run_mult(-320, 15);        -- -320 * 15 = -4800
        run_div(-4800, 19);        -- -4800 / 19 -> Q = -252, R = -12
        run_mult(-125, -80);       -- -125 * (-80) = 10000
        run_div(1250, -40);        -- 1250 / (-40) -> Q = -31, R = 10
        run_div_zero(999);         -- 999 / 0 -> div_zero_err = '1'
        run_mult(123, 10);         -- Verify normal operation resumes after div-by-zero

        report "=== ALL INTEGRATED MATH UNIT TESTS COMPLETED ===" severity note;
        wait;
    end process;

end architecture Test;
