----------------------------------------------------------------------------------
-- File: srt_radix4_cu.vhd
-- Description: Control Unit (FSM + Radix-4 SRT P-D Quotient Selection Table)
--              for 16-bit Signed Radix-4 SRT Divider.
--              Selects redundant quotient digits {-2, -1, 0, +1, +2} over
--              8 iterations (2 bits per cycle).
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity srt_radix4_cu is
    port (
        clk          : in  std_logic;
        reset        : in  std_logic;
        start        : in  std_logic;

        -- Status signals from Execution Unit (EU)
        div_by_zero  : in  std_logic;                    -- High if divisor is zero
        d_norm_done  : in  std_logic;                    -- High when divisor MSB is normalized
        count_zero   : in  std_logic;                    -- High during the 8th (final) iteration
        p4_top       : in  std_logic_vector(6 downto 0); -- Top 7 signed bits of 4*P (scaled by 2^13)
        d_top        : in  std_logic_vector(2 downto 0); -- Fractional bits D[15:13] of normalized divisor

        -- Control outputs to Execution Unit (EU)
        init_regs    : out std_logic;                    -- Capture inputs, signs, and reset counters
        norm_en      : out std_logic;                    -- Shift divisor & dividend left for normalization
        exec_en      : out std_logic;                    -- Execute P_{j+1} = 4*P_j - q*D and update Q
        corr_en      : out std_logic;                    -- Final negative remainder correction & sign restore
        q_digit      : out std_logic_vector(2 downto 0); -- Selected digit in 3-bit 2's complement (-2..+2)
        done         : out std_logic;                    -- Division completed flag
        ready        : out std_logic                     -- Module ready for new operation
    );
end entity srt_radix4_cu;

architecture Behavioral of srt_radix4_cu is
    type state_type is (ST_IDLE, ST_INIT, ST_NORM, ST_EVAL, ST_EXEC, ST_CORR, ST_DONE);
    signal current_state, next_state : state_type;
begin

    -- Sequential process for FSM state register
    state_reg_proc: process(clk, reset)
    begin
        if reset = '1' then
            current_state <= ST_IDLE;
        elsif rising_edge(clk) then
            current_state <= next_state;
        end if;
    end process;

    -- Combinational Radix-4 SRT P-D Selection Table
    -- Maps truncated 4*P (p4_top) and normalized divisor (d_top) to q_digit in {-2, -1, 0, +1, +2}
    pd_table_proc: process(p4_top, d_top)
        variable p_val : integer range -64 to 63;
        variable t1    : integer range 0 to 15;
        variable t2    : integer range 0 to 31;
        variable q_int : integer range -2 to 2;
    begin
        p_val := to_integer(signed(p4_top));

        -- Selection thresholds (scaled by 2^13) guaranteeing |P_{j+1}| <= (2/3)*D
        case d_top is
            when "000" => t1 := 4; t2 := 13; -- D in [8/16, 9/16)
            when "001" => t1 := 4; t2 := 14; -- D in [9/16, 10/16)
            when "010" => t1 := 5; t2 := 16; -- D in [10/16, 11/16)
            when "011" => t1 := 5; t2 := 17; -- D in [11/16, 12/16)
            when "100" => t1 := 6; t2 := 19; -- D in [12/16, 13/16)
            when "101" => t1 := 6; t2 := 20; -- D in [13/16, 14/16)
            when "110" => t1 := 7; t2 := 22; -- D in [14/16, 15/16)
            when others => t1 := 7; t2 := 23; -- D in [15/16, 16/16)
        end case;

        if p_val >= t2 then
            q_int := 2;
        elsif p_val >= t1 then
            q_int := 1;
        elsif p_val >= -t1 then
            q_int := 0;
        elsif p_val >= -t2 then
            q_int := -1;
        else
            q_int := -2;
        end if;

        q_digit <= std_logic_vector(to_signed(q_int, 3));
    end process;

    -- Combinational process for next-state logic and control signals
    fsm_comb_proc: process(current_state, start, div_by_zero, d_norm_done, count_zero)
    begin
        -- Default control signal values
        init_regs <= '0';
        norm_en   <= '0';
        exec_en   <= '0';
        corr_en   <= '0';
        done      <= '0';
        ready     <= '0';

        case current_state is
            when ST_IDLE =>
                ready <= '1';
                if start = '1' then
                    next_state <= ST_INIT;
                else
                    next_state <= ST_IDLE;
                end if;

            when ST_INIT =>
                init_regs <= '1';
                if div_by_zero = '1' then
                    next_state <= ST_DONE;
                else
                    next_state <= ST_NORM;
                end if;

            when ST_NORM =>
                if d_norm_done = '1' then
                    next_state <= ST_EVAL;
                else
                    norm_en    <= '1';
                    next_state <= ST_NORM;
                end if;

            when ST_EVAL =>
                -- Allow combinational P-D table to settle on current 4*P and D
                next_state <= ST_EXEC;

            when ST_EXEC =>
                exec_en <= '1';
                if count_zero = '1' then
                    next_state <= ST_CORR;
                else
                    next_state <= ST_EVAL;
                end if;

            when ST_CORR =>
                corr_en    <= '1';
                next_state <= ST_DONE;

            when ST_DONE =>
                done <= '1';
                if start = '0' then
                    next_state <= ST_IDLE;
                else
                    next_state <= ST_DONE;
                end if;

            when others =>
                next_state <= ST_IDLE;
        end case;
    end process;

end architecture Behavioral;
