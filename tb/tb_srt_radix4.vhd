----------------------------------------------------------------------------------
-- File: tb_srt_radix4.vhd
-- Description: Testbench for the 16-bit Signed Radix-4 SRT Divider.
--              Verifies signed integer division (quotient and remainder) across
--              all sign combinations, edge cases, and divide-by-zero detection.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_srt_radix4 is
end entity tb_srt_radix4;

architecture Test of tb_srt_radix4 is
    constant DATA_WIDTH : integer := 16;
    constant CLK_PERIOD : time := 10 ns;

    -- UUT Signals
    signal clk          : std_logic := '0';
    signal reset        : std_logic := '0';
    signal start        : std_logic := '0';
    signal dividend     : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal divisor      : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal ready        : std_logic;
    signal done         : std_logic;
    signal div_zero_err : std_logic;
    signal quotient     : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal remainder    : std_logic_vector(DATA_WIDTH-1 downto 0);

begin

    -- Instantiate Unit Under Test (UUT)
    UUT: entity work.srt_divider_top
        generic map (
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            clk          => clk,
            reset        => reset,
            start        => start,
            dividend     => dividend,
            divisor      => divisor,
            ready        => ready,
            done         => done,
            div_zero_err => div_zero_err,
            quotient     => quotient,
            remainder    => remainder
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
        -- Helper procedure to execute a standard division test case
        procedure run_test(val_dvd, val_dvs : in integer) is
            variable expected_q : integer;
            variable expected_r : integer;
            variable actual_q   : integer;
            variable actual_r   : integer;
        begin
            -- Ensure module is ready before applying inputs
            if ready /= '1' then
                wait until ready = '1';
            end if;

            wait until rising_edge(clk);

            dividend <= std_logic_vector(to_signed(val_dvd, DATA_WIDTH));
            divisor  <= std_logic_vector(to_signed(val_dvs, DATA_WIDTH));
            start    <= '1';
            wait until rising_edge(clk);
            start    <= '0';

            wait until done = '1';

            expected_q := val_dvd / val_dvs;
            expected_r := val_dvd rem val_dvs;
            actual_q   := to_integer(signed(quotient));
            actual_r   := to_integer(signed(remainder));

            -- Automated checks using assert
            assert (actual_q = expected_q) and (actual_r = expected_r) and (div_zero_err = '0')
                report "TEST FAILED: " & integer'image(val_dvd) & " / " & integer'image(val_dvs) &
                       " | Got Q=" & integer'image(actual_q) & ", R=" & integer'image(actual_r) &
                       " | Expected Q=" & integer'image(expected_q) & ", R=" & integer'image(expected_r)
                severity error;

            if (actual_q = expected_q) and (actual_r = expected_r) and (div_zero_err = '0') then
                report "TEST PASSED: " & integer'image(val_dvd) & " / " & integer'image(val_dvs) &
                       " -> Q=" & integer'image(expected_q) & ", R=" & integer'image(expected_r)
                       severity note;
            end if;

            wait for 20 ns;
        end procedure;

        -- Helper procedure to verify divide-by-zero protection
        procedure run_div_zero_test(val_dvd : in integer) is
        begin
            if ready /= '1' then
                wait until ready = '1';
            end if;

            wait until rising_edge(clk);

            dividend <= std_logic_vector(to_signed(val_dvd, DATA_WIDTH));
            divisor  <= (others => '0');
            start    <= '1';
            wait until rising_edge(clk);
            start    <= '0';

            wait until done = '1';

            assert div_zero_err = '1'
                report "DIV-BY-ZERO TEST FAILED: div_zero_err flag was not asserted!"
                severity error;

            if div_zero_err = '1' then
                report "TEST PASSED: " & integer'image(val_dvd) & " / 0 -> div_zero_err = '1'"
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

        -- Test Case 1: Positive / Positive with remainder
        run_test(100, 7);          -- 100 / 7 = 14, R = 2

        -- Test Case 2: Exact Positive / Positive
        run_test(4500, 15);        -- 4500 / 15 = 300, R = 0

        -- Test Case 3: Positive / Negative
        run_test(1250, -40);       -- 1250 / (-40) = -31, R = 10

        -- Test Case 4: Negative / Positive
        run_test(-1024, 15);       -- (-1024) / 15 = -68, R = -4

        -- Test Case 5: Negative / Negative
        run_test(-750, -30);       -- (-750) / (-30) = 25, R = 0
        run_test(-755, -30);       -- (-755) / (-30) = 25, R = -5

        -- Test Case 6: |Dividend| < |Divisor| (Quotient = 0, Remainder = Dividend)
        run_test(45, 120);         -- 45 / 120 = 0, R = 45
        run_test(-45, 120);        -- (-45) / 120 = 0, R = -45

        -- Test Case 7: Zero Dividend
        run_test(0, -25);          -- 0 / (-25) = 0, R = 0

        -- Test Case 8: Edge values (16-bit signed range)
        run_test(32767, 1);        -- 32767 / 1 = 32767, R = 0
        run_test(-32767, 127);     -- (-32767) / 127 = -258, R = -1

        -- Test Case 9: Divide by Zero detection
        run_div_zero_test(1234);

        report "=== SRT RADIX-4 DIVIDER TESTS COMPLETED ===" severity note;
        wait;
    end process;

end architecture Test;