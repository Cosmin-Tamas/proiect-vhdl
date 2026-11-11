----------------------------------------------------------------------------------
-- File: booth_radix4_cu.vhd
-- Description: Control Unit (FSM) for 16-bit Radix-4 Booth Multiplier.
--              Sequences initialization, evaluation, ALU operation execution,
--              2-bit arithmetic shift, and completion signaling.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity booth_radix4_cu is
    port (
        clk          : in  std_logic;
        reset        : in  std_logic;
        start        : in  std_logic;
        count_zero   : in  std_logic; -- Flag from EU indicating 8 iterations completed
        
        -- Control outputs to Execution Unit (EU)
        init_regs    : out std_logic; -- Reset accumulator A, load M and Q
        add_sub_en   : out std_logic; -- Enable ALU addition/subtraction
        op_select    : out std_logic_vector(1 downto 0); -- Operation selector: 00:+M, 01:-M, 10:+2M, 11:-2M
        shift_en     : out std_logic; -- Enable 2-bit Arithmetic Shift Right (ASR 2)
        done         : out std_logic; -- Operation completed status flag
        ready        : out std_logic  -- Module ready for new operation flag
    );
end entity booth_radix4_cu;

architecture Behavioral of booth_radix4_cu is
    type state_type is (ST_IDLE, ST_INIT, ST_EVALUATE, ST_EXEC_OP, ST_SHIFT, ST_DONE);
    signal current_state, next_state : state_type;
begin

    -- Sequential process for FSM state register
    process(clk, reset)
    begin
        if reset = '1' then
            current_state <= ST_IDLE;
        elsif rising_edge(clk) then
            current_state <= next_state;
        end if;
    end process;

    -- Combinational process for next-state logic and control outputs
    process(current_state, start, count_zero)
    begin
        -- Default signal output values
        init_regs  <= '0';
        add_sub_en <= '0';
        op_select  <= "00";
        shift_en   <= '0';
        done       <= '0';
        ready      <= '0';

        case current_state is
            when ST_IDLE =>
                ready <= '1';
                if start = '1' then
                    next_state <= ST_INIT;
                else
                    next_state <= ST_IDLE;
                end if;

            when ST_INIT =>
                init_regs  <= '1';
                next_state <= ST_EVALUATE;

            when ST_EVALUATE =>
                -- Evaluate Booth triplet (Q_1, Q_0, Q_-1) inside EU
                -- Proceed to ALU execution step
                next_state <= ST_EXEC_OP;

            when ST_EXEC_OP =>
                add_sub_en <= '1';
                next_state <= ST_SHIFT;

            when ST_SHIFT =>
                shift_en <= '1';
                if count_zero = '1' then
                    next_state <= ST_DONE;
                else
                    next_state <= ST_EVALUATE;
                end if;

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