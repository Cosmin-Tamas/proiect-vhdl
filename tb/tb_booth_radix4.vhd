----------------------------------------------------------------------------------
-- File: tb_booth_radix4.vhd
-- Description: Corrected Testbench for 16-bit Radix-4 Booth Multiplier.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_booth_radix4 is
end entity tb_booth_radix4;

architecture Test of tb_booth_radix4 is
    constant DATA_WIDTH : integer := 16;
    constant CLK_PERIOD : time := 10 ns;

    -- UUT Signals
    signal clk          : std_logic := '0';
    signal reset        : std_logic := '0';
    signal start        : std_logic := '0';
    signal multiplicand : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal multiplier   : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal ready        : std_logic;
    signal done         : std_logic;
    signal product      : std_logic_vector((2 * DATA_WIDTH)-1 downto 0);

begin

    -- Instantiate Unit Under Test (UUT)
    UUT: entity work.booth_multiplier_top
        generic map (
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            clk          => clk,
            reset        => reset,
            start        => start,
            multiplicand => multiplicand,
            multiplier   => multiplier,
            ready        => ready,
            done         => done,
            product      => product
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
        procedure run_test(val_m, val_q : in integer) is
            variable expected : integer;
            variable actual   : integer;
        begin
            -- Check if ready is not already '1' before waiting for event
            if ready /= '1' then
                wait until ready = '1';
            end if;
            
            wait until rising_edge(clk);
            
            multiplicand <= std_logic_vector(to_signed(val_m, DATA_WIDTH));
            multiplier   <= std_logic_vector(to_signed(val_q, DATA_WIDTH));
            start        <= '1';
            wait until rising_edge(clk);
            start        <= '0';

            wait until done = '1';
            
            expected := val_m * val_q;
            actual   := to_integer(signed(product));
            
            -- Automated check using assert
            assert actual = expected
                report "TEST FAILED: " & integer'image(val_m) & " * " & integer'image(val_q) &
                       " | Got: " & integer'image(actual) &
                       " | Expected: " & integer'image(expected)
                severity error;

            if actual = expected then
                report "TEST PASSED: " & integer'image(val_m) & " * " & integer'image(val_q) &
                       " = " & integer'image(expected)
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

        -- Test Case 1: Positive * Positive
        run_test(125, 40);       -- 125 * 40 = 5000

        -- Test Case 2: Positive * Negative
        run_test(500, -12);      -- 500 * (-12) = -6000

        -- Test Case 3: Negative * Positive
        run_test(-1024, 15);     -- (-1024) * 15 = -15360

        -- Test Case 4: Negative * Negative
        run_test(-250, -30);     -- (-250) * (-30) = 7500

        -- Test Case 5: Zero multiplication
        run_test(0, -450);       -- 0 * (-450) = 0

        -- Test Case 6: Edge values (Max/Min signed 16-bit range)
        run_test(32767, 1);      -- 32767 * 1 = 32767
        run_test(-32768, 1);     -- (-32768) * 1 = -32768

        report "=== BOOTH RADIX-4 MULTIPLIER TESTS COMPLETED ===" severity note;
        wait;
    end process;

end architecture Test;