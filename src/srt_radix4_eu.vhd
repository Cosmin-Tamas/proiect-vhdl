----------------------------------------------------------------------------------
-- File: srt_radix4_eu.vhd
-- Description: Execution Unit (Datapath) for 16-bit Signed Radix-4 SRT Divider.
--              Handles sign-magnitude conversion, dynamic divisor/dividend
--              normalization, partial remainder recurrence P_{j+1} = 4*P_j - q*D,
--              on-the-fly quotient accumulation, and final remainder correction.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity srt_radix4_eu is
    generic (
        DATA_WIDTH : integer := 16
    );
    port (
        clk          : in  std_logic;
        reset        : in  std_logic;
        dividend     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        divisor      : in  std_logic_vector(DATA_WIDTH-1 downto 0);

        -- Control signals from CU
        init_regs    : in  std_logic;
        norm_en      : in  std_logic;
        exec_en      : in  std_logic;
        corr_en      : in  std_logic;
        q_digit      : in  std_logic_vector(2 downto 0);

        -- Status signals to CU
        div_by_zero  : out std_logic;
        d_norm_done  : out std_logic;
        count_zero   : out std_logic;
        p4_top       : out std_logic_vector(6 downto 0);
        d_top        : out std_logic_vector(2 downto 0);

        -- Final outputs
        quotient     : out std_logic_vector(DATA_WIDTH-1 downto 0);
        remainder    : out std_logic_vector(DATA_WIDTH-1 downto 0);
        div_zero_err : out std_logic
    );
end entity srt_radix4_eu;

architecture Behavioral of srt_radix4_eu is
    -- Combined 36-bit partial remainder & dividend shift register:
    -- Upper 21 bits (35 downto 15): signed partial remainder P (bit 31 = weight 2^-1)
    -- Lower 15 bits (14 downto 0):  fractional dividend bits shifting into P
    signal reg_px       : signed(2*DATA_WIDTH + 3 downto 0); -- 36 bits (35 downto 0)

    -- Normalized divisor register (17 bits unsigned, bit 16 = normalized MSB = 0.5)
    signal reg_d_norm   : unsigned(DATA_WIDTH downto 0);

    -- On-the-fly quotient accumulator (17 bits signed to handle intermediate adjustments)
    signal reg_q        : signed(DATA_WIDTH downto 0);

    -- Sign registers and error flag
    signal sign_q       : std_logic;
    signal sign_r       : std_logic;
    signal err_flag     : std_logic;

    -- Counters for normalization shifts and 8 Radix-4 iterations
    signal norm_shifts  : integer range 0 to DATA_WIDTH;
    signal iter_cnt     : integer range 0 to DATA_WIDTH / 2;

    -- Combinational signals for 4*P and q*D arithmetic
    signal px_shifted   : signed(2*DATA_WIDTH + 3 downto 0);
    signal p4_val       : signed(DATA_WIDTH + 4 downto 0); -- 21 bits (20 downto 0)
    signal d_ext        : signed(DATA_WIDTH + 4 downto 0); -- 21 bits aligned with p4_val
    signal qd_term      : signed(DATA_WIDTH + 4 downto 0);
    signal p_next       : signed(DATA_WIDTH + 4 downto 0);

    -- Output registers
    signal q_out_reg    : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal r_out_reg    : std_logic_vector(DATA_WIDTH-1 downto 0);
begin

    -- Combinational divide-by-zero detection
    div_by_zero <= '1' when signed(divisor) = 0 else '0';

    -- Normalization complete when bit 16 of reg_d_norm is '1'
    d_norm_done <= reg_d_norm(DATA_WIDTH);

    -- Iteration counter flag (high during the 8th and final iteration)
    count_zero  <= '1' when iter_cnt <= 1 else '0';

    -- 2-bit left shift of combined {P, X} register to form 4*P
    px_shifted  <= reg_px(2*DATA_WIDTH + 1 downto 0) & signed'("00");
    p4_val      <= px_shifted(2*DATA_WIDTH + 3 downto DATA_WIDTH - 1); -- Top 21 bits (35 downto 15)

    -- Slice top 7 signed bits of 4*P (scaled by 2^13) and top 3 fractional bits of D
    p4_top      <= std_logic_vector(p4_val(19 downto 13));
    d_top       <= std_logic_vector(reg_d_norm(DATA_WIDTH - 1 downto DATA_WIDTH - 3));

    -- Sign-extend normalized divisor to 21 bits for ALU subtraction/addition
    d_ext       <= signed(std_logic_vector'("0000") & std_logic_vector(reg_d_norm));

    -- Combinational generation of q_digit * D for q_digit in {-2, -1, 0, +1, +2}
    qd_mux_proc: process(q_digit, d_ext)
        variable q_int : integer range -4 to 3;
        variable d_x2  : signed(DATA_WIDTH + 4 downto 0);
    begin
        q_int := to_integer(signed(q_digit));
        d_x2  := d_ext(DATA_WIDTH + 3 downto 0) & '0';
        case q_int is
            when 2      => qd_term <= d_x2;            -- +2*D
            when 1      => qd_term <= d_ext;           -- +1*D
            when -1     => qd_term <= -d_ext;          -- -1*D
            when -2     => qd_term <= -d_x2;           -- -2*D
            when others => qd_term <= (others => '0'); --  0*D
        end case;
    end process;

    -- Next partial remainder: P_{j+1} = 4*P_j - q_{j+1}*D
    p_next <= p4_val - qd_term;

    -- Output port assignments
    quotient     <= q_out_reg;
    remainder    <= r_out_reg;
    div_zero_err <= err_flag;

    -- Sequential datapath process
    seq_proc: process(clk, reset)
        variable dvd_mag    : signed(DATA_WIDTH downto 0);
        variable dvs_mag    : signed(DATA_WIDTH downto 0);
        variable abs_dvd    : unsigned(DATA_WIDTH-1 downto 0);
        variable abs_dvs    : unsigned(DATA_WIDTH-1 downto 0);
        variable q_step_int : integer range -4 to 3;
        variable p_final    : signed(DATA_WIDTH + 4 downto 0);
        variable q_final    : signed(DATA_WIDTH downto 0);
        variable rem_shifted: unsigned(DATA_WIDTH + 4 downto 0);
        variable rem_mag    : signed(DATA_WIDTH downto 0);
    begin
        if reset = '1' then
            reg_px      <= (others => '0');
            reg_d_norm  <= (others => '0');
            reg_q       <= (others => '0');
            sign_q      <= '0';
            sign_r      <= '0';
            err_flag    <= '0';
            norm_shifts <= 0;
            iter_cnt    <= 0;
            q_out_reg   <= (others => '0');
            r_out_reg   <= (others => '0');

        elsif rising_edge(clk) then
            -- 1. Initialization phase
            if init_regs = '1' then
                dvd_mag := abs(resize(signed(dividend), DATA_WIDTH + 1));
                dvs_mag := abs(resize(signed(divisor), DATA_WIDTH + 1));

                sign_q  <= dividend(DATA_WIDTH - 1) xor divisor(DATA_WIDTH - 1);
                sign_r  <= dividend(DATA_WIDTH - 1);

                abs_dvd := unsigned(dvd_mag(DATA_WIDTH - 1 downto 0));
                abs_dvs := unsigned(dvs_mag(DATA_WIDTH - 1 downto 0));

                if abs_dvs = 0 then
                    err_flag    <= '1';
                    reg_px      <= (others => '0');
                    reg_d_norm  <= (others => '0');
                    reg_q       <= (others => '0');
                    q_out_reg   <= (others => '0');
                    r_out_reg   <= (others => '0');
                    norm_shifts <= 0;
                    iter_cnt    <= 0;
                else
                    err_flag    <= '0';
                    -- Place abs_dvd in lower 16 bits of 36-bit reg_px (scaled by 2^-15)
                    reg_px      <= signed(std_logic_vector'(x"00000") & std_logic_vector(abs_dvd));
                    -- Place abs_dvs in bits (16 downto 1) of 17-bit reg_d_norm
                    reg_d_norm  <= abs_dvs & '0';
                    reg_q       <= (others => '0');
                    norm_shifts <= 0;
                    iter_cnt    <= DATA_WIDTH / 2; -- 8 iterations for 16-bit operands
                end if;

            -- 2. Normalization phase (left-shift D and {P, X} simultaneously)
            elsif norm_en = '1' then
                reg_d_norm  <= reg_d_norm(DATA_WIDTH - 1 downto 0) & '0';
                reg_px      <= reg_px(2*DATA_WIDTH + 2 downto 0) & '0';
                norm_shifts <= norm_shifts + 1;

            -- 3. SRT Iteration execution phase
            elsif exec_en = '1' then
                -- Update upper 21 bits with P_{j+1} and keep lower 15 shifted bits
                reg_px <= p_next & px_shifted(DATA_WIDTH - 2 downto 0);

                -- Accumulate quotient digit on-the-fly: Q <= 4*Q + q_digit
                q_step_int := to_integer(signed(q_digit));
                reg_q <= (reg_q(DATA_WIDTH - 2 downto 0) & signed'("00")) + to_signed(q_step_int, DATA_WIDTH + 1);

                if iter_cnt > 0 then
                    iter_cnt <= iter_cnt - 1;
                end if;

            -- 4. Final remainder correction & sign restoration phase
            elsif corr_en = '1' then
                p_final := reg_px(2*DATA_WIDTH + 3 downto DATA_WIDTH - 1);
                q_final := reg_q;

                -- If final partial remainder is negative, restore by adding D and decrementing Q
                if p_final < 0 then
                    p_final := p_final + d_ext;
                    q_final := q_final - 1;
                end if;

                -- Un-normalize remainder by shifting right by (norm_shifts + 1)
                rem_shifted := shift_right(unsigned(p_final), norm_shifts + 1);
                rem_mag     := signed('0' & std_logic_vector(rem_shifted(DATA_WIDTH - 1 downto 0)));

                -- Apply final sign to quotient
                if sign_q = '1' and q_final /= 0 then
                    q_final := -q_final;
                end if;
                q_out_reg <= std_logic_vector(q_final(DATA_WIDTH - 1 downto 0));

                -- Apply final sign to remainder (matches dividend sign)
                if sign_r = '1' and rem_mag /= 0 then
                    rem_mag := -rem_mag;
                end if;
                r_out_reg <= std_logic_vector(rem_mag(DATA_WIDTH - 1 downto 0));
            end if;
        end if;
    end process;

end architecture Behavioral;